#############################################################################
tune_memory()
{
	echo "Tuning the memory configuration"
	
	# Get the supporting utilities
	apt-get -y install hugepages

	# Resolve a "Background save may fail under low memory condition." warning
	sysctl vm.overcommit_memory=1

	# Disable the Transparent Huge Pages (THP) support in the kernel
	sudo hugeadm --thp-never
}

#############################################################################

tune_network()
{
	echo "Tuning the network configuration"
	
>/etc/sysctl.conf cat << EOF 
	# Disable syncookies (syncookies are not RFC compliant and can use too muche resources)
	net.ipv4.tcp_syncookies = 0
	# Basic TCP tuning
	net.ipv4.tcp_keepalive_time = 600
	net.ipv4.tcp_synack_retries = 3
	net.ipv4.tcp_syn_retries = 3
	# RFC1337
	net.ipv4.tcp_rfc1337 = 1
	# Defines the local port range that is used by TCP and UDP to choose the local port
	net.ipv4.ip_local_port_range = 1024 65535
	# Log packets with impossible addresses to kernel log
	net.ipv4.conf.all.log_martians = 1
	# Disable Explicit Congestion Notification in TCP
	net.ipv4.tcp_ecn = 0
	# Enable window scaling as defined in RFC1323
	net.ipv4.tcp_window_scaling = 1
	# Enable timestamps (RFC1323)
	net.ipv4.tcp_timestamps = 1
	# Enable select acknowledgments
	net.ipv4.tcp_sack = 1
	# Enable FACK congestion avoidance and fast restransmission
	net.ipv4.tcp_fack = 1
	# Allows TCP to send "duplicate" SACKs
	net.ipv4.tcp_dsack = 1
	# Controls IP packet forwarding
	net.ipv4.ip_forward = 0
	# No controls source route verification (RFC1812)
	net.ipv4.conf.default.rp_filter = 0
	# Enable fast recycling TIME-WAIT sockets
	net.ipv4.tcp_tw_recycle = 1
	net.ipv4.tcp_max_syn_backlog = 20000
	# How may times to retry before killing TCP connection, closed by our side
	net.ipv4.tcp_orphan_retries = 1
	# How long to keep sockets in the state FIN-WAIT-2 if we were the one closing the socket
	net.ipv4.tcp_fin_timeout = 20
	# Don't cache ssthresh from previous connection
	net.ipv4.tcp_no_metrics_save = 1
	net.ipv4.tcp_moderate_rcvbuf = 1
	# Increase Linux autotuning TCP buffer limits
	net.ipv4.tcp_rmem = 4096 87380 16777216
	net.ipv4.tcp_wmem = 4096 65536 16777216
	# increase TCP max buffer size
	net.core.rmem_max = 16777216
	net.core.wmem_max = 16777216
	net.core.netdev_max_backlog = 2500
	# Increase number of incoming connections
	net.core.somaxconn = 65000
EOF

	# Reload the networking settings
	/sbin/sysctl -p /etc/sysctl.conf
}

#############################################################################
