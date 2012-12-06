require 'non-haml'

#NonHaml.generate 'test/nh_out.c', 'test/nh.c', binding, './'
NonHaml.generate 'test/nh_out.c', 'test/basic.source', binding, './'
