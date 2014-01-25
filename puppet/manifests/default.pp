# Note I'm not defining any nodes since this particular VM is a single instance box.

# A replace in file hack needed to fix up the Tajo import SQL file
# Found: http://trac.cae.tntech.edu/infrastructure/browser/puppet/modules/common/manifests/defines/replace.pp?rev=169
define replace($file, $pattern, $replacement) {
  $pattern_no_slashes = regsubst($pattern, '/', '\\/', 'G', 'U')
  $replacement_no_slashes = regsubst($replacement, '/', '\\/', 'G', 'U')
  exec { "replace_${pattern}_${file}":
    command => "/usr/bin/perl -pi -e 's/${pattern_no_slashes}/${replacement_no_slashes}/' '${file}'",
    onlyif  => "/usr/bin/perl -ne 'BEGIN { \$ret = 1; } \$ret = 0 if /${pattern_no_slashes}/ && ! /\\Q${replacement_no_slashes}\\E/; END { exit \$ret; }' '${file}'",
    alias   => "exec_$name",
  }
}

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

file { "vagrant_ssh_private_key":
  ensure => "file",
  path => "/home/vagrant/.ssh/id_rsa",
  source => "puppet:///modules/hadoop/vagrant_insecure_private_key",
  mode => "600",
  owner => "vagrant",
  group => "vagrant",
  require => Class["hadoop"],
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
  ensure   => "latest",
  owner    => "vagrant",
  group    => "vagrant",
  provider => "git",
  source   => "$github_base/incubator-tajo.git",
  revision => "mondrian",
  require  => File["$src"],
}

notify { "compile_tajo_warn":
  message => "Starting Tajo compilation.  This might take up to 10 minutes with no further messages until completion.",
  before  => Exec["compile_tajo"],
}

exec { "compile_tajo":
  command   => "/bin/bash -c 'mvn package -DskipTests -Pdist'",
  creates   => "$tajo_home",
  cwd       => "$tajo_src",
  logoutput => "true",
  timeout   => "600",
  user      => "vagrant",
  require   => [ Package["protobuf-compiler"], Class["hadoop"], VcsRepo["$tajo_src"] ],
}

file { "copy_tajo_demo_data":
  path => "$tajo_home/demo",
  source => "$tajo_dist/demo",
  ensure => "directory",
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
  path => "/etc/profile.d/tajo-path.sh",
  content => "export TAJO_HOME=$tajo_home\n",
  owner   => "root",
  group   => "root",
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
  command   => "/bin/bash -c 'bin/start-tajo.sh'",
  creates   => "/tmp/tajo-vagrant-master.pid",
  cwd       => "$tajo_home",
  logoutput => "true",
  timeout   => "30",
  user      => "vagrant",
  returns   => ["0","2"],
  require   => File_line["tajo_env_hadoop_home"],
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

notify { "compile_mondrian_warn":
  message => "Starting Mondrian compilation.  This might take up to 10 minutes with no further messages until completion.",
  before  => Exec["compile_mondrian"],
}

exec { "compile_mondrian":
  command   => "/bin/bash -c 'ant compile'",
  creates   => "$mondrian_src/classes/",
  cwd       => "$mondrian_src",
  logoutput => "true",
  timeout   => "600",
  user      => "vagrant",
  require   => [ File["tajo_home"], VcsRepo["$mondrian_src"] ],
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
