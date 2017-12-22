{% for hostname in salt['mine.get']('host') %}
  {{hostname}}-file:
    - file.managed:
      - name: {{hostname}}.cfg
      #- source: salt://common/nagios/server/files/host.cfg 
      #- template: jinja
      - user: nagios
      - group: nagios
      - contents: |
          {{ grains['host'] }}
          
{% endfor %}
