package EnsEMBL::Web::Apache::Handlers;

use strict;

use Apache2::Const qw(:common :http :methods);
use Apache2::SizeLimit;
use Apache2::Connection;
use Apache2::URI;
use APR::URI;
use Config;
use Fcntl ':flock';
use Sys::Hostname;
use Time::HiRes qw(time);
use URI::Escape qw(uri_escape);

use SiteDefs;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Registry;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::SpeciesDefs;

use EnsEMBL::Web::Apache::DasHandler;
use EnsEMBL::Web::Apache::SSI;
use EnsEMBL::Web::Apache::SpeciesHandler;

our $species_defs = EnsEMBL::Web::SpeciesDefs->new;
our $MEMD         = EnsEMBL::Web::Cache->new;

our $BLAST_LAST_RUN;
our $LOAD_COMMAND;

BEGIN {
  $LOAD_COMMAND = $Config{'osname'} eq 'dec_osf' ? \&_load_command_alpha :
                  $Config{'osname'} eq 'linux'   ? \&_load_command_linux :
                                                   \&_load_command_null;
};

sub handler {
  my $r = shift; # Get the connection handler
  
  $ENSEMBL_WEB_REGISTRY->timer->set_name('REQUEST ' . $r->uri);
  
  my $u           = $r->parsed_uri;
  my $file        = $u->path;
  my $querystring = $u->query;
  
  my @web_cookies = EnsEMBL::Web::Cookie->retrieve($r, map {'name' => $_, 'encrypted' => 1}, $SiteDefs::ENSEMBL_SESSION_COOKIE, $SiteDefs::ENSEMBL_USER_COOKIE);
  my $cookies     = {
    'session_cookie'  => $web_cookies[0] || EnsEMBL::Web::Cookie->new($r, {'name' => $SiteDefs::ENSEMBL_SESSION_COOKIE, 'encrypted' => 1}),
    'user_cookie'     => $web_cookies[1] || EnsEMBL::Web::Cookie->new($r, {'name' => $SiteDefs::ENSEMBL_USER_COOKIE,    'encrypted' => 1})
  };

  my @raw_path = split '/', $file;
  shift @raw_path; # Always empty

  ## Simple redirect to VEP
  if ($raw_path[0] && $raw_path[0] =~ /^VEP$/i) {
    $r->uri('/info/vep.html');
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
      
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_PERMANENTLY;
  }

  my $aliases = $species_defs->multi_val('SPECIES_ALIASES') || {};
  my %species_map = (
    %$aliases,
    common => 'common',
    multi  => 'Multi',
    perl   => $SiteDefs::ENSEMBL_PRIMARY_SPECIES,
    map { lc($_) => $SiteDefs::ENSEMBL_SPECIES_ALIASES->{$_} } keys %$SiteDefs::ENSEMBL_SPECIES_ALIASES
  );

  $species_map{lc $_} = $_ for values %species_map; # Self-mapping

## EG  
  foreach ($species_defs->valid_species) {
    $species_map{lc($_)} = $_;
  }
## /EG
  
  ## Identify the species element, if any
  my ($species, @path_segments);
 
  ## Check for stable id URL (/id/ENSG000000nnnnnn) 
  ## and malformed Gene/Summary URLs from external users
  if (($raw_path[0] && $raw_path[0] =~ /^id$/i && $raw_path[1]) || ($raw_path[0] eq 'Gene' && $querystring =~ /g=/ )) {
    my ($stable_id, $object_type, $db_type, $uri);
    
    if ($raw_path[0] =~ /^id$/i) {
      $stable_id = $raw_path[1];
    } else {
      $querystring =~ /g=(\w+)/;
      $stable_id = $1;
    }
    
    my $unstripped_stable_id = $stable_id;
    
    $stable_id =~ s/\.[0-9]+$// if $stable_id =~ /^ENS/; ## Remove versioning for Ensembl ids

    ## Try to register stable_id adaptor so we can use that db (faster lookup)
    my %db = %{$species_defs->multidb->{'DATABASE_STABLE_IDS'} || {}};
    
    if (keys %db) {
      my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -species => 'multi',
        -group   => 'stable_ids',
        -host    => $db{'HOST'},
        -port    => $db{'PORT'},
        -user    => $db{'USER'},
        -pass    => $db{'PASS'},
        -dbname  => $db{'NAME'}
      );
    }

    ($species, $object_type, $db_type) = Bio::EnsEMBL::Registry->get_species_and_object_type($stable_id);
    
    if (!$species || !$object_type) {
      ## Maybe that wasn't versioning after all!
      ($species, $object_type, $db_type) = Bio::EnsEMBL::Registry->get_species_and_object_type($unstripped_stable_id);
      $stable_id = $unstripped_stable_id if($species && $object_type);
    }
    
    my $dir = $species ? "/$species/" : '/Multi/';
    my $uri = $dir."psychic?q=$stable_id";  

    if ($object_type) {
      $uri = $dir;
      
      if ($object_type eq 'Gene') {
        $uri .= "Gene/Summary?g=$stable_id";
      } elsif ($object_type eq 'Transcript') {
        $uri .= "Transcript/Summary?t=$stable_id";
      } elsif ($object_type eq 'Translation') {
        $uri .= "Transcript/ProteinSummary?t=$stable_id";
      } elsif ($object_type eq 'GeneTree') {
        $uri = "/Multi/GeneTree?gt=$stable_id";
      } 
    }
      
    $r->uri($uri);
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
      
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_PERMANENTLY;
  }

  my %lookup = map { $_ => 1 } $species_defs->valid_species;
  my $lookup_args = {
    sd     => $species_defs,
    map    => \%species_map,
    lookup => \%lookup,
    uri    => $r->unparsed_uri,
  };

  foreach (@raw_path) {
    $lookup_args->{'dir'} = $_;
    my $check = _check_species($lookup_args);
    if ($check && $check =~ /^http/) {
      $r->headers_out->set( Location => $check );
      return REDIRECT;
    }
    elsif ($check && !$species) {
      $species = $_;
    } else {
      push @path_segments, $_;
    }
  }
  
  if (!$species) {
    if (grep /$raw_path[0]/, qw(Multi das common default)) {
      $species = $raw_path[0];
      shift @path_segments;
    } elsif ($path_segments[0] eq 'Gene' && $querystring) {
      my %param = split ';|=', $querystring;
      if (my $gene_stable_id = $param{'g'}) {
        my ($id_species) = Bio::EnsEMBL::Registry->get_species_and_object_type($gene_stable_id);
        
        $species = $id_species if $id_species;
      }  
    }
  }
 
  @path_segments = @raw_path unless $species;
  
  # Some memcached tags (mainly for statistics)
  my $prefix = '';
  my @tags   = map { $prefix = join '/', $prefix, $_; $prefix; } @path_segments;
  
  if ($species) {
    @tags = map {( "/$species$_", $_ )} @tags;
    push @tags, "/$species";
  }
  
  $ENV{'CACHE_TAGS'}{$_} = $_ for @tags;
  
  my $Tspecies  = $species;
  my $script    = undef;
  my $path_info = undef;
  my $species_name = $species_map{lc $species};
  my $return;
  
  if (!$species && $raw_path[-1] !~ /\./) {
    $species      = 'common';
    $species_name = 'common';
    $file         = "/common$file";
    $file         =~ s|/$||;
  }
  
  if ($raw_path[0] eq 'das') {
    my ($das_species) = split /\./, $path_segments[0];
    
    $return = EnsEMBL::Web::Apache::DasHandler::handler_das($r, $cookies, $species_map{lc $das_species}, \@path_segments, $querystring);
    
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler for DAS scripts finished', undef, 'Apache');
  } elsif ($species && $species_name) { # species script
    $return = EnsEMBL::Web::Apache::SpeciesHandler::handler_species($r, $cookies, $species_name, \@path_segments, $querystring, $file, $species_name eq $species);
    
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler for species scripts finished', undef, 'Apache');
    
    shift @path_segments;
    shift @path_segments;
  }
  
  if (defined $return) {
    if ($return == OK) {
      push_script_line($r) if $SiteDefs::ENSEMBL_DEBUG_FLAGS & $SiteDefs::ENSEMBL_DEBUG_HANDLER_ERRORS;
      
      $r->push_handlers(PerlCleanupHandler => \&cleanupHandler_script);
      $r->push_handlers(PerlCleanupHandler => \&Apache2::SizeLimit::handler);
    }
    
    return $return;
  }
  
  $species = $Tspecies;
  $script = join '/', @path_segments;

  # Permanent redirect for old species home pages:
  # e.g. /Homo_sapiens or Homo_sapiens/index.html -> /Homo_sapiens/Info/Index
  if ($species && $species_name && (!$script || $script eq 'index.html')) {
    $r->uri($species_name eq 'common' ? 'index.html' : "/$species_name/Info/Index");
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_PERMANENTLY;
  }
  
  #commenting this line out because we do want biomart to redirect. If this is causing problem put it back.
  #return DECLINED if $species eq 'biomart' && $script =~ /^mart(service|results|view)/;

  my $path = join '/', $species || (), $script || (), $path_info || ();
  
  $r->uri("/$path");
  
  my $filename = $MEMD ? $MEMD->get("::STATIC::$path") : '';
  
  # Search the htdocs dirs for a file to return
  # Exclude static files (and no, html is not a static file in ensembl)
  if ($path !~ /\.(\w{2,3})$/) {
    if (!$filename) {
      foreach my $dir (grep { -d $_ && -r $_ } @SiteDefs::ENSEMBL_HTDOCS_DIRS) {
        my $f = "$dir/$path";
        
        if (-d $f || -r $f) {
          $filename = -d $f ? '! ' . $f : $f;
          $MEMD->set("::STATIC::$path", $filename, undef, 'STATIC') if $MEMD;
          
          last;
        }
      }
    }
  }
  
  if ($filename =~ /^! (.*)$/) {
    $r->uri($r->uri . ($r->uri      =~ /\/$/ ? '' : '/') . 'index.html');
    $r->filename($1 . ($r->filename =~ /\/$/ ? '' : '/') . 'index.html');
    $r->headers_out->add('Location' => $r->uri);
    $r->child_terminate;
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "REDIRECT"', undef, 'Apache');
    
    return HTTP_MOVED_TEMPORARILY;
  } elsif ($filename) {
    $r->filename($filename);
    $r->content_type('text/html');
    $ENSEMBL_WEB_REGISTRY->timer_push('Handler "OK"', undef, 'Apache');
    
    EnsEMBL::Web::Apache::SSI::handler($r, $cookies);
    
    return OK;
  }
  
  # Give up
  $ENSEMBL_WEB_REGISTRY->timer_push('Handler "DECLINED"', undef, 'Apache');
  
  return DECLINED;
}

1;
