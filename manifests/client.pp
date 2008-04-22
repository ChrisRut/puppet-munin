# client.pp - configure a munin node
# Copyright (C) 2007 David Schmitt <david@schmitt.edv-bus.at>
# See LICENSE for the full license granted to you.

class munin::client {

	$munin_port_real = $munin_port ? { '' => 4949, default => $munin_port } 
	$munin_host_real = $munin_host ? {
		'' => '*',
		'fqdn' => '*',
		default => $munin_host
	}

	case $operatingsystem {
		darwin: { include munin::client::darwin }
		debian: {
			include munin::client::debian
			include munin::plugins::debian
		}
		ubuntu: {
			info ( "Trying to configure Ubuntu's munin with Debian class" )
			include munin::client::debian
			include munin::plugins::debian
		}
		gentoo: {
			include munin::client::gentoo
			include munin::plugins::gentoo
		}
		centos: {
			include munin::client::centos
			include munin::plugins::centos
		}
		default: { fail ("Don't know how to handle munin on $operatingsystem") }
	}

	case $kernel {
		linux: {
			case $vserver {
				guest: { include munin::plugins::vserver }
				default: {
					include munin::plugins::linux
				}
			}
		}
		default: {
			err( "Don't know which munin plugins to install for $kernel" )
		}
	}
	case $virtual {
        physical: { include munin::plugins::physical }
	    xen0: { include munin::plugins::dom0 }
        xenu: { include munin::plugins::domU }
    }
}

define munin::register()
{
	$munin_port_real = $munin_port ? { '' => 4949, default => $munin_port } 
	$munin_host_real = $munin_host ? {
		'' => $fqdn,
		'fqdn' => $fqdn,
		default => $munin_host
	}

	@@file { "${NODESDIR}/${name}_${munin_port_real}":
		ensure => present,
		content => template("munin/defaultclient.erb"),
		tag => 'munin',
	}
}

define munin::register_snmp()
{
	@@file { "munin_snmp_${name}": path => "${NODESDIR}/${name}",
		ensure => present,
		content => template("munin/snmpclient.erb"),
		tag => 'munin',
	}
}

class munin::client::darwin 
{
	file { "/usr/share/snmp/snmpd.conf": 
		mode => 744,
		content => template("munin/darwin_snmpd.conf.erb"),
		group  => 0,
		owner  => root,
	}
	delete_matching_line{"startsnmpdno":
		file => "/etc/hostconfig",
		pattern => "SNMPSERVER=-NO-",
	}
	line { "startsnmpdyes":
		file => "/etc/hostconfig",
		line => "SNMPSERVER=-YES-",
		notify => Exec["/sbin/SystemStarter start SNMP"],
	}
	exec{"/sbin/SystemStarter start SNMP":
		noop => false,
	} 
	munin::register_snmp { $fqdn: }
}

class munin::client::debian 
{
	package { "munin-node": ensure => installed }
    # the plugin will need that
	package { "iproute": ensure => installed }

	file {
		"/etc/munin/":
			ensure => directory,
			mode => 0755, owner => root, group => 0;
		"/etc/munin/munin-node.conf":
			content => template("munin/munin-node.conf.${operatingsystem}.${lsbdistcodename}"),
			mode => 0644, owner => root, group => 0,
			# this has to be installed before the package, so the postinst can
			# boot the munin-node without failure!
			before => Package["munin-node"],
			notify => Service["munin-node"],
	}

	service { "munin-node":
		ensure => running, 
		# sarge's munin-node init script has no status
		hasstatus => $lsbdistcodename ? { sarge => false, default => true }
	}

	munin::register { $fqdn: }

	# workaround bug in munin_node_configure
	plugin { "postfix_mailvolume": ensure => absent }
}

class munin::client::gentoo 
{
    $acpi_available = "absent"
    package { 'munin-node':
                name => 'munin',
                ensure => present,
                category => $operatingsystem ? {
                        gentoo => 'net-analyzer',
                        default => '',
                },
    }

	file {
		"/etc/munin/":
			ensure => directory,
			mode => 0755, owner => root, group => 0;
		"/etc/munin/munin-node.conf":
			content => template("munin/munin-node.conf.Gentoo."),
			mode => 0644, owner => root, group => 0,
			# this has to be installed before the package, so the postinst can
			# boot the munin-node without failure!
			before => Package["munin-node"],
	    #		notify => Service["munin"],
	}

	service { "munin-node":
		ensure => running, 
	}

	munin::register { $fqdn: }
}

class munin::client::centos 
{
    package { 'munin-node':
                ensure => present,
    }


	file {
		"/etc/munin/":
			ensure => directory,
			mode => 0755, owner => root, group =>0;
		"/etc/munin/munin-node.conf":
			content => template("munin/munin-node.conf.CentOS."),
			mode => 0644, owner => root, group => 0,
			# this has to be installed before the package, so the postinst can
			# boot the munin-node without failure!
			before => Package["munin-node"],
			notify => Service["munin-node"],
	}

	service { "munin-node":
		ensure => running, 
	}

	munin::register { $fqdn: }

}