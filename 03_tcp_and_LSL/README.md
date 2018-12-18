The initial idea for the TCP connection was from: http://iheartmatlab.blogspot.de/2008/08/tcpip-socket-communications-in-matlab.html

To play around with the TCP connection between two PCs, use server_timing.m for the server side and client_timing.m for the client side, or if you prefer LSL* (which is recommended), then use LSL_test.m and LSL_test_for_server.m, respectively.

It's important to deactivate the delayed acknowledgement. For example, see http://www.justanswer.com/computer/3du1a-rid-200ms-delay-tcp-ip-ack-windows.html . For more info: https://support.microsoft.com/en-us/kb/214397 . 


*LSL is a very useful library that allows reliable streaming of data via a local network.

These links are very useful:
- get the code: https://github.com/sccn/labstreaminglayer
- a talk and the corresponding presentation slides: https://www.youtube.com/watch?v=Y1at7yrcFW0 & ftp://sccn.ucsd.edu/pub/bcilab/lectures/Demo_1_The_Lab_Streaming_Layer.pdf
- the LSL wiki with more advanced info: https://github.com/sccn/labstreaminglayer/wiki

Basic functions are quite easy to use, see https://github.com/sccn/labstreaminglayer/tree/master/LSL/liblsl-Matlab/examples
