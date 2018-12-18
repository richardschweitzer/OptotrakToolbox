The roundtrip demo is the opus magnum of the optotrak setup.

ROUNDTRIP.m and ROUNDTRIP_lsl.m are functions you run on the experimental host PC, while on the optotrak host PC you'll have to run the optotrak_sampling_server.m or optotrak_sampling_server_lsl.m , respectively.

As an alternative to the roundtrip, there are two demos that request and receive data without triggering the optotrak to produce a frame via the Datapixx: test_connect_and_receive.m is just receiving data, while test_connect_and_receive_and_plot.m is receiving and plotting it "real-time".

To setup a connection to the optotrak host PC, you can use the connect_to_optotrak_sampling_server.m.

To initialize the Datapixx, you may use startDatapixx.m. To shut it down later, you may use shutdownDatapixx.m.

You'll also need these two auxiliary mex functions to speed up the decoding process in the function receive_from_optotrak_sampling_server.m :

1. A fast method to split a string based on certain character: splitstr.mexa64 compiled (on Debian 8) from splitstr.c

2. A fast method to convert a string to a double: str2doubleq.mexa64 compiled from str2doubleq.cpp 
