unique template metaconfig/logstash/forwarder;

include metaconfig/logstash/version;

include format("metaconfig/logstash/formatter_%s", METACONFIG_LOGSTASH_VERSION);

include 'metaconfig/logstash/schema';

bind "/software/components/metaconfig/services/{/etc/logstash-forwarder.conf}/contents" = type_logstash_forwarder;

prefix "/software/components/metaconfig/services/{/etc/logstash-forwarder.conf}";
"daemons/logstash-forwarder" = "restart";
"owner" = "root";
"group" = "root";
"mode" = 0640;
"module" = format("logstash/forwarder");

