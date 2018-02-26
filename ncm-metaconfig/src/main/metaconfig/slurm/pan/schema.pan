declaration template metaconfig/slurm/schema;

@{ Schema for slurm configuration, see
https://slurm.schedmd.com
}

include 'pan/types';

type slurm_conf_control = {
    'ControlMachine' : string
    'ControlAddr' ? type_ipv4
    'BackupController' ? string
    'BackupAddr' ? type_ipv4
    'AuthType' : choice('munge')
    'CheckpointType' ? choice('none')
    'CryptoType' : choice('munge', 'openssl')
    'DisableRootJobs' : boolean
    'EnforcePartLimits': boolean
    #'Epilog'=
    #'EpilogSlurmctld'=
    'FirstJobId' ? long
    'MaxJobId' ? long
    #'GresTypes'=
    'GroupUpdateForce' ? long
    'GroupUpdateTime' ? long
    'JobCheckpointDir' : absolute_file_path
    #'JobCredentialPrivateKey'=
    #'JobCredentialPublicCertificate'=
    #'JobFileAppend'=0
    #'JobRequeue'=1
    'JobSubmitPlugins' ? choice('lua')
    #'KillOnBadExit'=0
    #'LaunchType'=launch/slurm
    #'Licenses'=foo    '4,bar'
    'MailProg' ? absolute_file_path
    'MaxJobCount' ? long
    'MaxStepCount' ? long
    'MaxTasksPerNode' ? long
    'MpiDefault' : string
    #'MpiParams'=ports=#-#
    'PluginDir' ? absolute_file_path
    #'PlugStackConfig'=
    'PrivateData' : string[]
    'ProctrackType' : choice('cgroup', 'cray', 'linuxproc', 'lua', 'sgi_job', 'pgid')
    #'Prolog'=
    #'PrologFlags'=
    #'PrologSlurmctld'=
    #'PropagatePrioProcess'=0
    #'PropagateResourceLimits'=
    #'PropagateResourceLimitsExcept'=
    #'RebootProgram'=
    'ReturnToService' : long(0..2)
    #'SallocDefaultCommand'=
};

type slurm_conf_process = {
    'SlurmctldPidFile' : absolute_file_path
    'SlurmctldPort' : long
    'SlurmdPidFile' : absolute_file_path
    'SlurmdPort' : long
    'SlurmdSpoolDir' : absolute_file_path
    'SlurmUser' : string = 'slurm'
    'SlurmdUser' ? string = 'root'
    #'SrunEpilog'=
    #'SrunProlog'=
    'StateSaveLocation' : absolute_file_path
    'SwitchType' ? choice('cray', 'none', 'nrt')
    #'TaskEpilog'=
    'TaskPlugin' : choice('affinity', 'cgroup', 'none')[]
    'TaskPluginParam' : dict
    #'TaskProlog'=
    #'TopologyPlugin'=topology/tree
    #'TmpFS'=/tmp
    #'TrackWCKey'=no
    #'TreeWidth'=
    #'UnkillableStepProgram'=
    #'UsePAM'=0
};


type slurm_conf_timers = {
    #'BatchStartTimeout'=10
    #'CompleteWait'=0
    #'EpilogMsgTime'=2000
    #'GetEnvTimeout'=2
    #'HealthCheckInterval'=0
    #'HealthCheckProgram'=
    'InactiveLimit' : long(0..)
    'KillWait' : long(0..)
    #'MessageTimeout'=10
    #'ResvOverRun'=0
    'MinJobAge' : long(0..)
    #'OverTimeLimit'=0
    'SlurmctldTimeout' : long(0..)
    'SlurmdTimeout' : long(0..)
    #'UnkillableStepTimeout'=60
    #'VSizeFactor'=0
    'Waittime' : long(0..)
};

type slurm_conf_scheduling = {
    'DefMemPerCPU' ? long(0..)
    'DefMemPerNode' ? long(0..)
    'FastSchedule' : long
    'MaxMemPerNode' : long(0..)
    #'SchedulerTimeSlice'=30
    'SchedulerType' : choice('backfill', 'builtin', 'hold')
    'SchedulerParameters': dict
    'SelectType' ? choice('bluegene', 'cons_res', 'cray', 'linear', 'serial')
    'SelectTypeParameters' ? dict
};


type slurm_conf_job_priority = {
    'PriorityFlags' ? string[]
    'PriorityType' : choice('multifactor', 'basic')
    @{in minutes}
    'PriorityDecayHalfLife' ? long(0..)
    'PriorityCalcPeriod' ? long(0..)
    'PriorityFavorSmall' ? boolean
    @{in minutes}
    'PriorityMaxAge' ? long(0..)
    #'PriorityUsageResetPeriod'=
    'PriorityWeightAge' ? long(0..)
    'PriorityWeightFairshare' ? long(0..)
    'PriorityWeightJobSize' ? long(0..)
    'PriorityWeightPartition' ? long(0..)
    'PriorityWeightQOS' ? long(0..)
};

type slurm_conf_accounting = {
    'AccountingStorageEnforce' ? string[]
    'AccountingStorageHost' ? string
    'AccountingStorageLoc' ? absolute_file_path
    #'AccountingStoragePass'=
    #'AccountingStoragePort'=
    'AccountingStorageType' ? choice('filetxt', 'none', 'slurmdbd')
    #'AccountingStorageUser'=
    'AccountingStoreJobComment' ? boolean
    'ClusterName' : string
    #'DebugFlags'=
    'JobCompHost' ? string
    'JobCompLoc' ? string
    'JobCompPass' ? string
    'JobCompPort' ? long(0..)
    'JobCompType' ? choice('elastcisearch', 'filetxt', 'mysql', 'none')
    'JobCompUser' ? string
    'JobContainerType'? choice('none')
    'JobAcctGatherFrequency' ? long(0..)
    'JobAcctGatherType' ? choice('cgroup', 'linux', 'none')
};

type slurm_conf_logging = {
    'SlurmctldDebug' ? long(0..)
    'SlurmctldLogFile' : absolute_file_path
    'SlurmdDebug' ? long(0..)
    'SlurmdLogFile' : absolute_file_path
    #'SlurmdLogFile'=
    #'SlurmSchedLogFile'=
    #'SlurmSchedLogLevel'=
};

type slurm_conf_power = {
    #'SuspendProgram'=
    #'ResumeProgram'=
    #'SuspendTimeout'=
    #'ResumeTimeout'=
    #'ResumeRate'=
    #'SuspendExcNodes'=
    #'SuspendExcParts'=
    #'SuspendRate'=
    #'SuspendTime'=
};

type slurm_conf_nodes = {
    'NodeName' ? string[]
    'CPUs' : long(0..)
    'Sockets' : long(0..)
    'CoresPerSocket' : long(0..)
    'ThreadsPerCore' : long(0..)
    'State' : choice('UNKNOWN', 'UP', 'DOWN')
    @{in MiB}
    'RealMemory': long(0..)
};

type slurm_conf_partition = {
    'Nodes' : string[]
    'Default' ? boolean
    @{in minutes}
    'MaxTime' : long
    'State' : choice('UNKNOWN', 'UP', 'DOWN')
    'DisableRootJobs' ? boolean
};


type slurm_conf = {
    'control' : slurm_conf_control
    'process' : slurm_conf_process
    'timers' : slurm_conf_timers
    'scheduling' : slurm_conf_scheduling
    'priority' : slurm_conf_job_priority
    'accounting' : slurm_conf_accounting
    'logging' : slurm_conf_logging
    'power' ? slurm_conf_power
    @{key is used as nodename, unless NodeName attribute is set}
    'nodes' : slurm_conf_nodes{}
    @{key is the PartitionName}
    'partitions' : slurm_conf_partition{}
};


type slurm_cgroups_conf = {
    'CgroupAutomount' ? boolean
    'CgroupMountpoint' ? absolute_file_path
    'AllowedDevicesFile' ? absolute_file_path
    'AllowedKmemSpace' ? long(0..)
    'AllowedRAMSpace' ? long(0..)
    'AllowedSwapSpace' ? long(0..)
    'ConstrainCores' ? boolean
    'ConstrainDevices' ? boolean
    'ConstrainKmemSpace' ? boolean
    'ConstrainRAMSpace' ? boolean
    'ConstrainSwapSpace' ? boolean
    'MaxRAMPercent' ? double(0..100)
    'MaxSwapPercent' ? double(0..100)
    'MaxKmemPercent' ? double(0..100)
    'MemorySwappiness' ? long(0..100)
    'MinKmemSpace' ? long(0..)
    'MinRAMSpace' ? long(0..)
    'TaskAffinity' ? boolean
};

type slurm_spank_plugin = {
    @{plugin is optional (if not optional, it is required)}
    'optional' ? boolean
    'path' : absolute_file_path
    'arguments' ? dict()
};

type slurm_spank_includes = {
    'directory' : absolute_file_path
};

type slurm_plugstack_conf = {
    'plugins' : slurm_spank_plugin[]
    'includes' ? slurm_spank_includes[]
};

type slurm_dbd_conf = {
    'ArchiveDir' ? absolute_file_path
    'ArchiveEvents' ? boolean
    'ArchiveJobs' ? boolean
    'ArchiveResvs' ? boolean
    'ArchiveScript' ? absolute_file_path
    'ArchiveSteps' ? boolean
    'ArchiveSuspend' ? boolean
    'ArchiveTXN' ? boolean
    'ArchiveUsage' ? boolean
    'AuthInfo' ? string
    'AuthType' ? choice('none', 'munge')
    'CommitDelay' ? long(1..)
    'DbdBackupHost' ? string
    'DbdAddr' ? string
    'DbdHost' ? string
    'DbdPort' ? long(0..) with SELF == value('/software/components/metaconfig/services/' +
        '{/etc/slurm/slurm.conf}/accounting/AccountingStoragePort')
    'DebugFlags' ? choice('DB_ARCHIVE', 'DB_ASSOC', 'DB_EVENT', 'DB_JOB', 'DB_QOS', 'DB_QUERY', 'DB_RESERVATION',
                            'DB_RESOURCE', 'DB_STEP', 'DB_USAGE', 'DB_WCKEY', 'FEDERATION')[]
    'DebugLevel' ? choice('quiet', 'fatal', 'error', 'info', 'verbose',
                            'debug', 'debug2', 'debug3', 'debug4', 'debug5')
    'DebugLevelSyslog' ? choice('quiet', 'fatal', 'error', 'info', 'verbose',
                                'debug', 'debug2', 'debug3', 'debug4', 'debug5')
    'DefaultQOS' ? string
    'LogFile' ? absolute_file_path
    'LogTimeFormat' ? choice("iso8601", "iso8601_ms", "rfc5424", "rfc5424_ms", "clock", "short")
    'MaxQueryTimeRange' ? long(0..)  # unsure of this type
    'MessageTimeout' ? long(0..)
    'PidFile' ? absolute_file_path
    'PluginDir' ? absolute_file_path
    'PrivateData' ? choice( 'accounts', 'events', 'jobs', 'reservations', 'usage', 'users')[]
    @{in hours}
    'PurgeEventAfter' ? long(1..)
    @{in hours}
    'PurgeJobAfter' ? long(1..)
    @{in hours}
    'PurgeResvAfter' ? long(1..)
    @{in hours}
    'PurgeStepAfter' ? long(1..)
    @{in hours}
    'PurgeSuspendAfter' ? long(1..)
    @{in hours}
    'PurgeTXNAfter' ? long(1..)
    @{in hours}
    'PurgeUsageAfter' ? long(1..)
    'SlurmUser' ? string
    'StorageHost' ? string
    'StorageBackupHost' ? string
    'StorageLoc' ? absolute_file_path
    'StoragePass' ? string
    'StoragePort' ? long(0..)
    'StorageType' ? choice("mysql")
    'StorageUser' ? string
    'TCPTimeout' ? long(0..)
    'TrackWCKey' ? boolean
    'TrackSlurmctldDown' ? boolean
};
