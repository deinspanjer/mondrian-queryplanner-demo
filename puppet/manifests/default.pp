# Note I'm not defining any nodes since this particular VM is a single instance box.

package { ["vim",
           "curl",
           "bash"]:
  ensure => present,
}


$mysql_override_options = {
  'mysqld' => {
    'query_cache_limit' => '128M',
    'query_cache_size'  => '256M',
    'query_cache_type'  => '1',
  },
  'mysqld_safe' => {
    # Set the MySQL timezone.
    # @see http://stackoverflow.com/questions/947299/how-do-i-make-mysqls-now-and-curdate-functions-use-utc
    'timezone' => 'UTC',
  },
}
$mysql_users = {
  'foodmart@localhost' => {
    ensure        => 'present',
    password_hash => mysql_password('foodmart'),
  },
}
$mysql_grants = {
  'foodmart@localhost/*.*' => {
     ensure     => 'present',
     options    => ['GRANT'],
     privileges => ['ALL'],
     table      => '*.*',
     user       => 'foodmart@localhost',
  },
}
$mysql_databases = {
  'steelwheels' => {
    ensure  => 'present',
    charset => 'utf8',
  },
}
class { '::mysql::server':
  override_options => $mysql_override_options,
  databases        => $mysql_databases,
  users            => $mysql_users,
  grants           => $mysql_grants,
}



class { 'java':
  distribution => 'jdk',
  version      => 'latest',
}


file_line { "java_home":
  path => "/etc/profile",
  line => "export JAVA_HOME=${java::java_home}",
}


class { '::mysql::bindings':
  java_enable => 1,
  require => [ Class['java'], Class['::mysql::server'] ],
}


package { ["ant",
           "maven"]:
  ensure => present,
  require => Class['java'],
}


class { 'hadoop':
  require => Class['java'],
}


file { '/src':
  ensure => 'directory',
  owner => 'vagrant',
  group => 'vagrant',
}

vcsrepo { '/src/mondrian-tajo':
  ensure => latest,
  provider => git,
  source => 'git://github.com/DEinspanjer/mondrian.git',
  revision => 'tajo',
  require => File['/src'],
}

vcsrepo { '/src/tajo-mondrian':
  ensure => latest,
  provider => git,
  source => 'git://github.com/DEinspanjer/incubator-tajo.git',
  revision => 'mondrian',
  require => File['/src'],
}

include apt
apt::ppa { 'ppa:chris-lea/protobuf': }
package { ['protobuf-compiler', 'libprotobuf-dev']:
  ensure => present,
  require => Apt::Ppa['ppa:chris-lea/protobuf'],
}
