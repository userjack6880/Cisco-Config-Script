#!/bin/env perl

# note that on the ten gigabit interfaces, they can be configured as gigabit as
# well... so the uplink_pre is defined as "te/0/|gi1/0/" and split at the pipe. 
# that way, the 1-gig interface is setup as well. 

our %ciscoModels = (
# 2950 - 48
	"WS-C2950G-48-EI"    => { "num_ports"    => 48,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

# 2950 - 24
	"WS-C2950G-24-EI"    => { "num_ports"    => 24,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
                          },

# 2960 - 48
	"WS-C2960-48TT-L"    => { "num_ports"    => 48,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
                          },

	"WS-C2960-48TC-L"    => { "num_ports"    => 48,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

# 2960 - 24
	"WS-C2960-24TT-L"    => { "num_ports"    => 24,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

	"WS-C2960-24TC-L"    => { "num_ports"    => 24,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

# 2960g - 48
	"WS-C2960G-48TC-L"   => { "num_ports"    => 44,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

# 2960g - 24
	"WS-C2960G-24TC-L"   => { "num_ports"    => 20,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
                            "num_uplinks"  => 4,
                            "uplink_pre"   => "gi0/",
                            "poe"          => 0
                          },

# 2960c - 12
	"WS-C2960C-12PC-L"   => { "num_ports"    => 12,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 1
	                        },

# 2960cg - 8
	"WS-C2960CG-8TL-L"   => { "num_ports"    => 8,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

# 2960cpd - 8
	"WS-C2960CPD-8PT-L"  => { "num_ports"    => 8,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 1
	                        },

	"WS-C2960CPD-8TT-L"  => { "num_ports"    => 8,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },
# 2960cx - 8
	"WS-C2960CX-8PC-L"   => { "num_ports"    => 8,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 1
	                        },

	"WS-C2960CX-8TC-L"   => { "num_ports"    => 8,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },
# 2960c - 8
	"WS-C2960C-8PC-L"    => { "num_ports"    => 8,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 1
	                        },

	"WS-C2960C-8TC-L"    => { "num_ports"    => 8,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

	"WS-C2960C-8TC-S"    => { "num_ports"    => 8,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 0
	                        },

# 2960s - 24
	"WS-C2960S-24PD-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960S-24TD-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960S-24PS-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960S-24TS-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960S-24TS-S"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

# 2960s - 48
	"WS-C2960S-48FPD-L"  => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 2,
	                           "uplink_pre"   => "te1/0/|gi1/0/",
                             "poe"          => 1
	                        },

	"WS-C2960S-48LPD-L"  => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 2,
	                           "uplink_pre"   => "te1/0/|gi1/0/",
	                           "poe"          => 1
	                        },

	"WS-C2960S-48TD-L"   => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 2,
	                           "uplink_pre"   => "te1/0/|gi1/0/",
	                           "poe"          => 0
	                         },

	"WS-C2960S-48FPS-L"  => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 4,
	                           "uplink_pre"   => "gi1/0/",
	                           "poe"          => 1
	                         },

	"WS-C2960S-48LPS-L"  => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 4,
	                           "uplink_pre"   => "gi1/0/",
	                           "poe"          => 1
	                         },

	"WS-C2960S-48TS-L"   => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 4,
	                           "uplink_pre"   => "gi1/0/",
	                           "poe"          => 0
	                         },

	"WS-C2960S-48TS-S"   => {  "num_ports"    => 48,
	                           "port_type"    => "gigabitethernet",
	                           "port_prefix"  => "gi1/0/",
	                           "num_uplinks"  => 2,
	                           "uplink_pre"   => "gi1/0/",
	                           "poe"          => 0
	                         },

# 2960x - 24
	"WS-C2960X-24PD-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-24TD-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960X-24PS-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-24TS-L"   => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960X-24PSQ-L"  => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-24TS-LL"  => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

# 2960x - 48
	"WS-C2960X-48FPD-L"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-48LPD-L"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-48TD-L"   => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960X-48FPS-L"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-48LPS-L"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960X-48TS-L"   => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960X-48TS-LL"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

# 2960xr - 24
	"WS-C2960XR-24PD-I"  => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960XR-24TD-I"  => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960XR-24PS-I"  => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960XR-24TS-I"  => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

# 2960xr - 48
	"WS-C2960XR-48FPD-I" => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960XR-48LPD-I"=> { "num_ports"    => 48,
	                         "port_type"    => "gigabitethernet",
	                         "port_prefix"  => "gi1/0/",
	                         "num_uplinks"  => 2,
	                         "uplink_pre"   => "te1/0/|gi1/0/",
	                         "poe"          => 1
	                       },

	"WS-C2960XR-48TD-I"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te1/0/|gi1/0/",
	                          "poe"          => 0
	                        },

	"WS-C2960XR-48FPS-I" => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960XR-48LPS-I" => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 1
	                        },

	"WS-C2960XR-48TS-I"  => { "num_ports"    => 48,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "gi1/0/",
	                          "poe"          => 0
	                        },

# 3550
	"WS-C3550-12G"       => { "num_ports"    => 12,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 0,
	                          "uplink_pre"   => "",
	                          "poe"          => 0
	                        },

# 3560
	"WS-C3560-24PS-S"    => { "num_ports"    => 24,
	                          "port_type"    => "fastethernet",
	                          "port_prefix"  => "fa0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "gi0/",
	                          "poe"          => 1
	                        },

# 3560CX
	"WS-C3560CX-8PC-S"   => { "num_ports"    => 8,
                            "port_type"    => "gigabitethernet",
                            "port_prefix"  => "gi0/",
                            "num_uplinks"  => 4,
                            "uplink_pre"   => "gi0/",
                            "poe"          => 1
                          },

	"WS-C3560CX-12PC-S"   => { "num_ports"    => 12,
                            "port_type"    => "gigabitethernet",
                            "port_prefix"  => "gi0/",
                            "num_uplinks"  => 4,
                            "uplink_pre"   => "gi0/",
                            "poe"          => 1
                          },

# 3560E - 24
	"WS-C3560E-24TD"     => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te0/",
	                          "poe"          => 0
	                        },

	"WS-C3560E-24PD"     => { "num_ports"    => 24,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te0/",
	                          "poe"          => 1
	                        },

# 3560E - 12
	"WS-C3560E-12SD"     => { "num_ports"    => 12,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi0/",
	                          "num_uplinks"  => 2,
	                          "uplink_pre"   => "te0/",
	                          "poe"          => 0
	                        },

# 3750G
	"WS-C3750G-12S-S"    => { "num_ports"    => 12,
	                          "port_type"    => "gigabitethernet",
	                          "port_prefix"  => "gi1/0/",
	                          "num_uplinks"  => 0,
	                          "uplink_pre"   => "",
	                          "poe"          => 0
	                        },


# 4500X
	"WS-C4500X-16"       => { "num_ports"    => 16,
	                          "port_type"    => "tengigabitethernet",
	                          "port_prefix"  => "te1/",
	                          "num_uplinks"  => 0,
	                          "uplink_pre"   => "",
	                          "poe"          => 0
	                        },

# 3850XS
	"WS-C3850-12XS"       => { "num_ports"    => 12,
	                          "port_type"    => "tengigabitethernet",
	                          "port_prefix"  => "te1/0/",
	                          "num_uplinks"  => 4,
	                          "uplink_pre"   => "te1/1/",
	                          "poe"          => 0
	                        },

# 9200
	"C9200L-24T-4G"       => { "num_ports"   => 24,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "gi1/1/",
	                           "poe"         => 0
                           },

	"C9200L-24P-4G"       => { "num_ports"   => 24,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "gi1/1/",
	                           "poe"         => 1
                           },

	"C9200L-24T-4X"       => { "num_ports"   => 24,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "te1/1/",
	                           "poe"         => 0
                           },

	"C9200L-24P-4X"       => { "num_ports"   => 24,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "te1/1/",
	                           "poe"         => 1
                           },

	"C9200L-48T-4G"       => { "num_ports"   => 48,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "gi1/1/",
	                           "poe"         => 0
                           },

	"C9200L-48P-4G"       => { "num_ports"   => 48,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "gi1/1/",
	                           "poe"         => 1
                           },

	"C9200L-48T-4X"       => { "num_ports"   => 48,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "te1/1/",
	                           "poe"         => 0
                           },

	"C9200L-48P-4X"       => { "num_ports"   => 48,
	                           "port_type"   => "gigabitethernet",
	                           "port_prefix" => "gi1/0/",
	                           "num_uplinks" => 4,
	                           "uplink_pre"  => "te1/1/",
	                           "poe"         => 0
                           },

# 9300
	"C9300-24T"           => { "num_ports"   => 24,
                             "port_type"   => "gigabitethernet",
                             "port_prefix" => "gi1/0/",
                             "num_uplinks" => 8,
                             "uplink_pre"  => "te1/1/",
															"poe"        => 1
                           },

# 9500
	"C9500-16X"           => { "num_ports"   => 16,
                             "port_type"   => "tengigabitethernet",
                             "port_prefix" => "te1/0/",
                             "num_uplinks" => 8,
                             "uplink_pre"  => "te1/1/|fo1/1/",
															"poe"        => 0
                           },

	"C9500-24Y4C"         => { "num_ports"   => 24,
                             "port_type"   => "twentyfivegigabitethernet",
                             "port_prefix" => "twe1/0/",
                             "num_uplinks" => 4,
                             "uplink_pre"  => "hu1/0/",
															"poe"        => 0
                           },

# IE-4000
	"IE-4000-4GS8GP4G-E" => { "num_ports"    => 16,
	                          "port_type"    => "gigabitethernet",
				  "port_prefix"  => "gi1/",
				  "num_uplinks"  => 0,
				  "uplink_pre"   => "",
				  "poe"          => 1
				},

);

