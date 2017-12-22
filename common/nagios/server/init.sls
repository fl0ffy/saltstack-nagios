nagios-install-prereqs:
  pkg.installed:
    - pkgs:
      - gcc
      - glibc
      - glibc-common
      - gd
      - gd-devel
      - make
      - net-snmp
      - openssl-devel
      - xinetd
      - unzip
      - httpd
      - php
      - php-cli

nagios-source-pkg:
  file.managed:
    - name: /root/nagios-4.3.2.tar.gz
    - source: salt://common/nagios/server/files/source/nagios-4.3.2.tar.gz
    - user: root
    - group: root
    - mode: '0644'

nagios-plugins-source-pkg:
  file.managed:
    - name: /root/nagios-plugins-2.2.1.tar.gz
    - source: salt://common/nagios/server/files/source/nagios-plugins-2.2.1.tar.gz
    - user: root
    - group: root
    - mode: '0644'

nagios-user:
  user.present:
    - name: nagios
    - shell: /sbin/nologin

apache-user-group:
  group.present:
    - name: nagios
    - members:
      - apache
    - require:
      - nagios-user

nagcmd-group:
  group.present:
    - name: nagcmd
    - members:
      - apache
      - nagios
    - require:
      - nagios-install-prereqs
      - nagios-user

#nagios-fw-port:
#  iptables.insert:
#    - position: 2
#    - table: filter
#    - chain: input
#    - jump: ACCEPT
#    - match: state
#    - connstate: NEW
#    - dport: 5667
#    - proto: tcp
#    - sport: 1025:65535
#    - save: True

install-nagios:
  cmd.run:
    - name: |
        cd /root
        tar xvzf nagios-4.3.2.tar.gz
        cd nagios-4.3.2
        ./configure --prefix=/opt/nagios --sysconfdir=/opt/nagios/etc --localstatedir=/opt/nagios/var --with-nagios-user=nagios --with-nagios-group=nagios --with-nagios-command-group=nagcmd
        make all
        make install
        make install-init
        make install-config
        make install-commandmode
        make install-webconf
        cp -R contrib/eventhandlers/ /opt/nagios/libexec/
        chown -R nagios.nagios /opt/nagios/libexec/eventhandlers
        ln -s /opt/nagios/etc /etc/nagios
        rm -rf /opt/nagios/etc/objects/*
    - cwd: /root
    - shell: /bin/bash
    - unless: test -f /etc/nagios/resource.cfg
    - require:
      - nagios-source-pkg
      - nagios-install-prereqs
      - nagcmd-group
      - nagios-user
      - apache-user-group

install-nagios-plugins:
  cmd.run:
    - name : |
        cd /root
        tar xvzf nagios-plugins-2.2.1.tar.gz
        cd nagios-plugins-2.2.1
        ./configure --prefix=/opt/nagios --sysconfdir=/opt/nagios/etc --localstatedir=/opt/nagios/var --with-nagios-user=nagios --with-nagios-group=nagios
        make
        make install
    - cwd: /root
    - shell: /bin/bash
    - unless: test -f /opt/nagios/libexec/check_ping
    - require:
      - nagios-plugins-source-pkg
      - install-nagios

nagios-service:
  service.running:
    - name: nagios
    - enable: true
    - reload: true
    - require:
      - install-nagios
      - install-nagios-plugins
      - /opt/nagios/etc

nagios-httpd-service:
  service.running:
    - name: httpd
    - enable: true
    - reload: true
    - init_delay: 5
    - require:
      - nagios-install-prereqs
    - watch:
      - nagios-service

set-base-index.html:
  file.managed:
    - name: /var/www/html/index.html
    - contents:
      - poop
    - user: root
    - group: root
    - mode: '0755'
    - create: True
    - require:
      - nagios-install-prereqs
    - notify:
      - nagios-httpd-service

setup-nagios-https:
  file.uncomment:
    - name: /etc/httpd/conf.d/nagios.conf
    - regex: SSLRequireSSL

/opt/nagios/etc:
  file.recurse:
    - name: /opt/nagios/etc/
    - source: salt://common/nagios/server/files/etc
    - user: nagios
    - group: nagios
    - dir_mode: '0755'
    - file_mode: '0644'
    - include_empty: True
    - require:
      - install-nagios
    - notify:
      - nagios-service

