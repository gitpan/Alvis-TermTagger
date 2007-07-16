use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'Alvis::TermTagger',
     dist_version_from => 'lib/Alvis/TermTagger.pm',
     license => 'gpl',
     requires => {'perl' => '5.005',
		  Getopt::Long => 0,
		  Pod::Usage => 0,
		  },
     installdirs => 'core',
     );

$build->create_build_script;
