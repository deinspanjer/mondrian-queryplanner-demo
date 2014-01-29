# Note I'm not defining any nodes since this particular VM is a single instance box.

include apt
apt::ppa { "ppa:chris-lea/protobuf": }
package { ["protobuf-compiler",
           "libprotobuf-dev"]:
  ensure  => present,
  require => Apt::Ppa["ppa:chris-lea/protobuf"],
}

package { ["vim",
           "curl",
           "perl",
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
->
exec { "fixjdk":
  path    => "/usr/bin:/usr/sbin:/bin:/sbin",
  command => "update-java-alternatives --set ${java::use_java_alternative}",
}

file { "java_home":
  path    => "/etc/profile.d/java-path.sh",
  content => "export JAVA_HOME=${java::java_home}\n",
  owner   => root,
  group   => root,
  require => Class["java"],
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

include "demo_build"
