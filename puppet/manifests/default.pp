# Note I'm not defining any nodes since this particular VM is a single instance box.

# Some constants
$github_base = "git://github.com/deinspanjer"
$src = "/src"

$mondrian_src = "$src/mondrian"

$tajo_src = "$src/tajo"
$tajo_dist = "$tajo_src/tajo-dist"
$tajo_home = "$tajo_dist/target/tajo-0.8.0-SNAPSHOT"


package { ["vim",
           "curl",
           "bash"]:
  ensure => present,
}


$mysql_override_options = {
  "mysqld" => {
    "query_cache_limit" => "128M",
    "query_cache_size"  => "256M",
    "query_cache_type"  => "1",
  },
  "mysqld_safe" => {
    "timezone" => "UTC",
  },
}
class { "::mysql::server":
  override_options => $mysql_override_options,
}



class { "java":
  distribution => "jdk",
  version      => "latest",
}


file { "java_home":
  path    => "/etc/profile.d/java-path.sh",
  content => "export JAVA_HOME=${java::java_home}\n",
  owner   => root,
  group   => root,
}


class { "::mysql::bindings":
  java_enable => 1,
  require     => [ Class["java"], Class["::mysql::server"] ],
}


package { ["ant",
           "maven"]:
  ensure  => present,
  require => Class["java"],
}


class { "hadoop":
  require => Class["java"],
}

include apt
apt::ppa { "ppa:chris-lea/protobuf": }
package { ["protobuf-compiler",
           "libprotobuf-dev"]:
  ensure  => present,
  require => Apt::Ppa["ppa:chris-lea/protobuf"],
}

file { "$src":
  ensure => "directory",
  owner  => "vagrant",
  group  => "vagrant",
}

vcsrepo { "$tajo_src":
  ensure   => latest,
  owner    => "vagrant",
  group    => "vagrant",
  provider => git,
  source   => "$github_base/incubator-tajo.git",
  revision => "mondrian",
  require  => File["$src"],
}


exec { "compile_tajo":
  command => "/bin/bash -c 'mvn package -DskipTests -Pdist'",
  creates => "$tajo_dist/target/tajo-0.8.0-SNAPSHOT",
  cwd => "$tajo_src",
  user => "vagrant",
  require => [ Package["protobuf-compiler"], Class["hadoop"], VcsRepo["$tajo_src"] ],
}

file { "tajo_home":
  path => "/etc/profile.d/tajo-path.sh",
  content => "export TAJO_HOME=$tajo_home\n",
  owner   => root,
  group   => root,
  require => Exec["compile_tajo"],
}

vcsrepo { "$mondrian_src":
  ensure   => latest,
  owner    => "vagrant",
  group    => "vagrant",
  provider => git,
  source   => "$github_base/mondrian.git",
  revision => "tajo",
  require  => File["$src"],
}

notify { "compile_mondrian":
  require => [ Exec["compile_tajo"], VcsRepo["$mondrian_src"] ],
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
  require => [ Class["::mysql::server"], Mysql::Db["steelwheels"] ],
}
