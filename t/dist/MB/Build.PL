use Module::Build;
Module::Build->new(
  module_name       => "MB",
  dist_version      => 1,
  license           => "perl",
)->create_build_script;
