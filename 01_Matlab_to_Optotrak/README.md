The Matlab_to_Optotrak() mex-Function Matlab_to_Optotrak.mexw32 makes it possible to communicate with the Optotrak from Matlab.

It is built from the mexFunction.cpp file, which includes almost all commands from the Optotrak API that are necessary to setup a collection, add rigid bodies, request and retrieve data, write to the buffer etc.

The idea is based on Jarrod Blinch (see the two documentations matlab_optotrak_sep_2015.docx and How_to_control_Optotrak_from_Matlab_on_64-bit_platform.docx, which explain how to produce a proper mex-file), but the functions on non-blocking methods, rigid objects, external triggers of the present file are implemented by Richard Schweitzer. The Visual Studio Project files can be found in Matlab_to_Optotrak_15092016.zip 
