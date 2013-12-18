
use strict;
use warnings;

use Module::Build 0.3601;
use lib qw{inc}; use Alien::Libarchive::ModuleBuild;

my %module_build_args = (
  "alien_build_commands" => [
    "%x -I../../inc -MAlien::Libarchive::ModuleBuild -e alien_patch",
    "%pconfigure --prefix=%s --disable-bsdtar --disable-bsdcpio",
    "make",
    "make DESTDIR=%d/_test install"
  ],
  "alien_name" => "libarchive",
  "alien_repository" => {
    "host" => "www.libarchive.org",
    "location" => "/downloads/",
    "pattern" => qr/(^libarchive-([\d\.]+)\.tar\.gz$)/,
    "protocol" => "http"
  },
  "build_requires" => {},
  "configure_requires" => {
    "Alien::Base" => "0.002",
    "File::ShareDir" => "1.03"
  },
  "dist_abstract" => "Build and make available libarchive",
  "dist_author" => [
    "Graham Ollis <plicease\@cpan.org>"
  ],
  "dist_name" => "Alien-Libarchive",
  "dist_version" => "0.09",
  "license" => "perl",
  "module_name" => "Alien::Libarchive",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Alien::Base" => "0.002",
    "Capture::Tiny" => 0,
    "ExtUtils::CChecker" => 0,
    "File::ShareDir" => "1.03",
    "perl" => "5.006"
  },
  "script_files" => [],
  "test_requires" => {
    "Test::CChecker" => 0,
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "Test::CChecker" => 0,
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

if ( $^O eq 'MSWin32' ) {
	$module_build_args{requires}{'Alien::Libarchive::MSWin32'} = '0';
}

my $build = Alien::Libarchive::ModuleBuild->new(%module_build_args);

$build->create_build_script;
