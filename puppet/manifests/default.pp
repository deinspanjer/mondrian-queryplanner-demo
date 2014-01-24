# Note I'm not defining any nodes since this particular VM is a single instance box.

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
    # Set the MySQL timezone.
    # @see http://stackoverflow.com/questions/947299/how-do-i-make-mysqls-now-and-curdate-functions-use-utc
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


file_line { "java_home":
  path => "/etc/profile",
  line => "export JAVA_HOME=${java::java_home}",
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
# TODO: How will I reference these packages in my require statement later on?

file { "/src":
  ensure => "directory",
  owner  => "vagrant",
  group  => "vagrant",
}

vcsrepo { "/src/tajo":
  ensure   => latest,
  provider => git,
  source   => "git://github.com/deinspanjer/incubator-tajo.git",
  revision => "mondrian",
  require  => File["/src"],
}


vcsrepo { "/src/mondrian":
  ensure   => latest,
  provider => git,
  source   => "git://github.com/deinspanjer/mondrian.git",
  revision => "tajo",
  require  => File["/src"],
}

mysql::db { "steelwheels":
  ensure   => "present",
  charset  => "utf8",
  collate  => "utf8_swedish_ci",
  user     => "foodmart",
  password => "foodmart",
  sql      => "/src/mondrian-tajo/demo/mysql/SteelWheels.sql",
  require  => [ VcsRepo["/src/mondrian"], Class["::mysql::server"] ],
}

mysql_grant { "foodmart@localhost/*.*":
  ensure     => "present",
  options    => ["GRANT"],
  privileges => ["ALL"],
  table      => "*.*",
  user       => "foodmart@localhost",
  require => [ Class["::mysql::server"], Mysql::Db["steelwheels"] ],
}
