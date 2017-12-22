#install prerequisite packages
nrpe-install-prereqs:
  pkg.installed:
    - pkgs:
      - gcc
      - glibc
      - glibc-common
      - make
      - perl
      - openssl-devel
      - krb5-devel

nrpe-source-pkg:
  file.managed:
    - name: /root/nrpe-3.1.0.tar.gz
    - source: salt://common/nagios/client/files/source/nrpe-3.1.0.tar.gz

nagios-plugins-source-pkg:
  file.managed:
    - name: /root/nagios-plugins-2.2.1.tar.gz
    - source: salt://common/nagios/client/files/source/nagios-plugins-2.2.1.tar.gz

nagios-user:
  user.present:
    - name: nagios
    - shell: /sbin/nologin

#install nrpe from source
install-nrpe:
  cmd.run:
    - name: |
        cd /root
        tar xvzf nrpe-3.1.0.tar.gz
        cd nrpe-3.1.0
        ./configure --prefix=/opt/nagios --exec-prefix=/opt/nagios --enable-ssl --enable-command-args --enable-bash-command-substitution --with-opsys=linux --with-dist-type=rh --with-init-type=sysv --with-nrpe-user=nagios --with-nrpe-group=nagios --with-nagios-user=nagios --with-nagios-group=nagios
        make
        make all
        make install
        make install-config
        make install-init
        ln -s /opt/nagios/etc /etc/nagios
    - cwd: /root
    - shell: /bin/bash
    - timeout: 300
    - unless: test -f /etc/nagios/nrpe.cfg
    - require:
      - nrpe-source-pkg
      - nrpe-install-prereqs
      - nagios-user

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
      - install-nrpe

/opt/nagios/etc/nrpe.cfg:
  file.managed:
    - name: /opt/nagios/etc/nrpe.cfg
    - source: salt://common/nagios/client/files/nrpe.cfg
    - template: jinja
    - user: nagios
    - group: nagios
    - mode: 640
    - require:
      - install-nrpe

nrpe-service:
  service.running:
    - name: nrpe
    - enable: true
    - reload: true
    - require:
      - install-nrpe
    - watch:
      - /opt/nagios/etc/nrpe.cfg

