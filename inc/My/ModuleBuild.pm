package My::ModuleBuild;

use strict;
use warnings;
use base qw( Module::Build );
use Config;
use Alien::Libarchive::Installer;
use File::Spec;
use FindBin ();

my $type = eval { require FFI::Raw } ? 'both' : 'compile';

# Note: for historical / hysterical reasons, the install type is one of:
# 1. system, use the system libarchive
# 2. share, build your own libarchive, both static and shared
#    the static version will be used for XS modules and the shared one
#    will be used for FFI modules.

sub _list ($)
{
  ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]];
}

sub _catfile {
  my $path = File::Spec->catfile(@_);
  $path =~ s{\\}{/}g if $^O eq 'MSWin32';
  $path;
}

sub _catdir {
  my $path = File::Spec->catdir(@_);
  $path =~ s{\\}{/}g if $^O eq 'MSWin32';
  $path;
}

sub new
{
  my($class, %args) = @_;

  my $system;

  unless(($ENV{ALIEN_LIBARCHIVE} || 'system') eq 'share')
  {
    $system = eval {
      Alien::Libarchive::Installer->system_install(
        type  => $type,
        alien => 0,
      )
    };
  }

  unless(defined $system)
  {
    my $prereqs = Alien::Libarchive::Installer->build_requires;  
    while(my($mod,$ver) = each %$prereqs)
    {
      $args{build_requires}->{$mod} = $ver;
    }
  }

  my $self = $class->SUPER::new(%args);

  $self->config_data( name => 'libarchive' );
  $self->config_data( already_built => 0 );
  $self->config_data( msvc => $^O eq 'MSWin32' && $Config{cc} =~ /cl(\.exe)?$/i ? 1 : 0 );
  
  $self->add_to_cleanup( '_alien', '_alien_libarchive', '_alien_bz2', 'share/libarchive019' );
  
  if(defined $system)
  {
    print "Found libarchive " . $system->version . " from system\n";
    print "You can set ALIEN_LIBARCHIVE=share to force building from source\n";
    $self->config_data( install_type => 'system' );
    $self->config_data( cflags       => _list $system->cflags );
    $self->config_data( libs         => _list $system->libs );
  }
  else
  {
    print "Did not find working libarchive, will download and install from the Internet\n";
    $self->config_data( install_type => 'share' );
  }
  
  $self;
}

sub ACTION_build
{
  my $self = shift;
  
  if($self->config_data('install_type') eq 'share')
  {
    unless($self->config_data('already_built'))
    {
      my $prefix = _catdir($FindBin::Bin, 'share', 'libarchive019' );

      local $ENV{CONFIG_SITE};

      if(eval { require Alien::bz2::Installer; })
      {
        my $build = eval { Alien::bz2::Installer->system_install };
        unless($build)
        {
          my $build_dir = _catdir($FindBin::Bin, '_alien_bz2');
          mkdir $build_dir unless -d $build_dir;
          $build = eval { Alien::bz2::Installer->build_install($prefix, dir => $build_dir) };
        }
        
        if(defined $build)
        {
          my $dir = _catdir($FindBin::Bin, '_alien');
          mkdir $dir;
          my $config_site = _catfile($dir, 'config.site');
          open my $fh, '>', $config_site;
          print $fh "#!/bin/sh\n";
          print $fh "CPPFLAGS=\"", join(' ', grep /^-I/, @{ $build->cflags}), "\"\n";
          print $fh "LDFLAGS=\"",  join(' ', grep /^-L/, @{ $build->libs  }), "\"\n";
          close $fh;
          # this is probably not necessary...
          eval { chmod 0755, $config_site };
          $ENV{CONFIG_SITE} = $config_site;
        }
      }
    
      my $build_dir = _catdir($FindBin::Bin, '_alien_libarchive');
      mkdir $build_dir unless -d $build_dir;
      mkdir $prefix unless -d $prefix;
      my $build = Alien::Libarchive::Installer->build_install( $prefix, dir => $build_dir );
      $self->config_data( cflags => [grep !/^-I/, @{ _list $build->cflags }] );
      $self->config_data( libs =>   [grep !/^-L/, @{ _list $build->libs }] );
      if($self->config_data('msvc'))
      {
        $self->config_data( libs =>   [grep !/^(\/|-)libpath/i, @{ _list $build->libs }] );
      }

      printf "cflags: %s\n", join ' ', @{ $self->config_data('cflags') };
      printf "libs:   %s\n", join ' ', @{ $self->config_data('libs') };
      printf "msvc:   %d\n", $self->config_data('msvc');
      
      do {
        opendir my $dh, _catdir($prefix, 'dll');
        my @list = grep { ! -l _catfile($prefix, 'dll', $_) }
                   grep { /\.so/ || /\.(dll|dylib)$/ }
                   grep !/^(libbz2|bzip2.dll)/,
                   grep !/^\./,
                   sort
                   readdir $dh;
        closedir $dh;
        print "dlls:\n";
        print "  - $_\n" for @list;
        $self->config_data( dlls => \@list );
      };
      
      $self->config_data( already_built => 1 );
    }
  }
  
  $self->SUPER::ACTION_build(@_);
}

1;
