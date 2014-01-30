class demo_build {
  # A replace in file hack needed to fix up the Tajo import SQL file
  # Found: http://trac.cae.tntech.edu/infrastructure/browser/puppet/modules/common/manifests/defines/replace.pp?rev=169
  define replace($file, $pattern, $replacement) {
    $pattern_no_slashes = regsubst($pattern, '/', '\\/', 'G', 'U')
    $replacement_no_slashes = regsubst($replacement, '/', '\\/', 'G', 'U')
    exec { "replace_${pattern}_${file}":
      command => "/usr/bin/perl -pi -e 's/${pattern_no_slashes}/${replacement_no_slashes}/' '${file}'",
      onlyif  => "/usr/bin/perl -ne 'BEGIN { \$ret = 1; } \$ret = 0 if /${pattern_no_slashes}/ && ! /\\Q${replacement_no_slashes}\\E/; END { exit \$ret; }' '${file}'",
      alias   => "exec_$name",
      require => Package["perl"],
    }
  }
  
  # Some constants
  $github_base  = "git://github.com/deinspanjer"
  $src          = "/src"
  $mondrian_src = "$src/mondrian"
  $tajo_src     = "$src/tajo"
  $tajo_dist    = "$tajo_src/tajo-dist"
  $tajo_home    = "$tajo_dist/target/tajo-0.8.0-SNAPSHOT"
  
  file { "ln_hadoop":
    path    => "/home/vagrant/hadoop",
    target  => "${hadoop::hadoop_home}",
    ensure  => "link",
    require => Class["hadoop"],
  }
  
  file { "vagrant_ssh_private_key":
    ensure  => "file",
    path    => "/home/vagrant/.ssh/id_rsa",
    source  => "puppet:///modules/demo_build/vagrant_insecure_private_key",
    mode    => "600",
    owner   => "vagrant",
    group   => "vagrant",
    require => Class["hadoop"],
  }

  file { "vagrant_ssh_known_host":
    ensure  => "file",
    path    => "/home/vagrant/.ssh/known_hosts",
    content => generate("/usr/bin/ssh-keyscan","localhost"),
    mode    => "600",
    owner   => "vagrant",
    group   => "vagrant",
    replace => "false",
    require => File["vagrant_ssh_private_key"],
  }
  
  file { "$src":
    ensure => "directory",
    owner  => "vagrant",
    group  => "vagrant",
  }
  
  vcsrepo { "$tajo_src":
    ensure   => "latest",
    owner    => "vagrant",
    group    => "vagrant",
    provider => "git",
    source   => "$github_base/incubator-tajo.git",
    revision => "mondrian",
    require  => File["$src"],
  }
  
  exec { "compile_tajo":
    command   => "/bin/bash -lc 'USER=vagrant mvn package -DskipTests -Pdist'",
    creates   => "$tajo_home",
    cwd       => "$tajo_src",
    logoutput => "true",
    timeout   => "600",
    user      => "vagrant",
    require   => [ Exec["fixjdk"], Package["protobuf-compiler"], Class["hadoop"], VcsRepo["$tajo_src"] ],
  }
  
  file { "copy_tajo_demo_data":
    path    => "$tajo_home/demo",
    source  => "$tajo_dist/demo",
    ensure  => "directory",
    recurse => "true",
    replace => "false",
    require => Exec["compile_tajo"],
  }
  
  replace { "interpolate_tajo_demo_data":
    file        => "$tajo_home/demo/steelwheels/SteelWheels.sql",
    pattern     => "TAJO_HOME",
    replacement => "$tajo_home",
    require     => File["copy_tajo_demo_data"],
  }
  
  file { "tajo_home":
    path    => "/etc/profile.d/tajo-path.sh",
    content => "export TAJO_HOME=$tajo_home\n",
    owner   => "root",
    group   => "root",
    require => Exec["compile_tajo"],
  }
  
  file { "ln_tajo":
    path    => "/home/vagrant/tajo",
    target  => "$tajo_home",
    ensure  => "link",
    require => Exec["compile_tajo"],
  }

  file_line { "tajo_env_java_home":
    path    => "$tajo_home/conf/tajo-env.sh",
    line    => "export JAVA_HOME=${java::java_home}",
    match   => "^(# )?export JAVA_HOME=/usr",
    require => Exec["compile_tajo"],
  }
  
  file_line { "tajo_env_hadoop_home":
    path    => "$tajo_home/conf/tajo-env.sh",
    line    => "export HADOOP_HOME=${hadoop::hadoop_home}",
    match   => "^(# )?export HADOOP_HOME=",
    require => File_line["tajo_env_java_home"],
  }
  
  exec { "start_tajo":
    command   => "/bin/bash -lc 'java -version; bin/start-tajo.sh'",
    creates   => "/tmp/tajo-vagrant-master.pid",
    cwd       => "$tajo_home",
    logoutput => "true",
    timeout   => "30",
    user      => "vagrant",
    require   => [ File["vagrant_ssh_known_host"], File_line["tajo_env_hadoop_home"] ],
  }
  
  exec { "load_tajo_demo_data":
    command   => "/bin/bash -lc 'USER=vagrant bin/tsql -f $tajo_home/demo/steelwheels/SteelWheels.sql'",
    creates   => "/tmp/tajo-vagrant-demo-data-loaded",
    cwd       => "$tajo_home",
    logoutput => "true",
    timeout   => "60",
    user      => "vagrant",
    require   => [ Exec["start_tajo"], Replace["interpolate_tajo_demo_data"] ],
  }
  
  file { "tajo_demo_data_loaded_flag":
    path    => "/tmp/tajo-vagrant-demo-data-loaded",
    content => "1",
    require => Exec["load_tajo_demo_data"],
  }
  
  vcsrepo { "$mondrian_src":
    ensure   => "latest",
    owner    => "vagrant",
    group    => "vagrant",
    provider => "git",
    source   => "$github_base/mondrian.git",
    revision => "tajo",
    require  => File["$src"],
  }

  file { "mondrian_properties":
    path    => "$mondrian_src/mondrian.properties",
    source  => "puppet:///modules/demo_build/demo.mondrian.properties",
    owner   => vagrant,
    group   => vagrant,
    require => VcsRepo["$mondrian_src"],
  }
  
  exec { "compile_mondrian":
    command   => "/bin/bash -lc 'USER=vagrant TAJO_HOME=$tajo_home HADOOP_HOME=${hadoop::hadoop_home} ant -Dtests.skip=true jar'",
    creates   => "$mondrian_src/classes/",
    cwd       => "$mondrian_src",
    logoutput => "true",
    timeout   => "600",
    user      => "vagrant",
    require   => [ Exec["fixjdk"], File["mondrian_properties"], File["tajo_home"] ],
  }

  file { "ln_mondrian":
    path    => "/home/vagrant/mondrian",
    target  => "$mondrian_src",
    ensure  => "link",
    require => VcsRepo["$mondrian_src"],
  }
  
  mysql::db { "steelwheels":
    ensure   => "present",
    charset  => "utf8",
    collate  => "utf8_swedish_ci",
    user     => "foodmart",
    password => "foodmart",
    sql      => "$mondrian_src/demo/mysql/SteelWheels.sql",
    require  => [ VcsRepo["$mondrian_src"], Class["::mysql::server"] ],
  }
  
  mysql_grant { "foodmart@localhost/*.*":
    ensure     => "present",
    options    => ["GRANT"],
    privileges => ["ALL"],
    table      => "*.*",
    user       => "foodmart@localhost",
    require    => [ Class["::mysql::server"], Mysql::Db["steelwheels"] ],
  }
}
