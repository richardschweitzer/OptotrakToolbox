// Written by Jarrod Blinch, August 2015
// Available from motorbehaviour.wordpress.com
// Additional commands included by Richard Schweitzer, July 2016

#include "mex.h"
#include <iostream>

#include <matrix.h>
#include <string.h>
#include <windows.h>
#include <math.h>

#include "ndtypes.h"
#include "ndpack.h"
#include "ndopto.h"

#include <stdio.h>
#include <stdlib.h>

#include <time.h>

/*
* Type definition to retreive and access rigid body transformation
* data.
*/
typedef struct RigidBodyDataStruct
{
	struct OptotrakRigidStruct  pRigidData[3];
	Position3d                  p3dData[9];
} RigidBodyDataType;

/*
* This is where the function starts
*/
void mexFunction(int nlhs, mxArray* plhs[], int nrhs, mxArray* prhs[]) {
	int
		return_code;
	unsigned int
		uRealtimeDataReady = 0,
		uSpoolComplete = 0,
		uSpoolStatus = 0,
		uFrameNumber,
		uElements,
		uFlags,
		uRigidCnt,
		ui,
		markers_on_port_1,		// how many markers on SCU port 1
		markers_on_port_2,		// how many markers on SCU port 2
		uj;
	static int
		puRawData[3 + 1];		// number of ODAU channels + 1
	static Position3d
		p3dData[1],
		p3dBackup[1];
	static OptotrakRigidStruct
		pRigidData[1];
	RigidBodyDataType
		RigidBodyData;
	char
		StrBuffer[65],
		StrBuffer2[65],
		StrBuffer3[65],
		filename_input[68],
		filename_output[68];
		//szNDErrorString[2048];	// 2047 + 1 (ndopto.h) MAX_ERROR_STRING_LENGTH + 1
	double
		*y,
		dk,
		dl;
	LARGE_INTEGER 
		frequency;        // ticks per second
		QueryPerformanceFrequency(&frequency);
	LARGE_INTEGER 
		t1, tstart, tend;           // ticks	
		QueryPerformanceCounter(&tstart);
	
	// Make sure there is only one argument.
	if (nrhs < 1) {
		mexErrMsgTxt("At least one string argument must be passed!\n");
	}

	// Make sure the argument is a string.
	if (!mxIsChar(prhs[0])) {
		mexErrMsgTxt("The first argument should be a string!\n");
	}

	// Read the string into StrBuffer.
	if (mxGetString(prhs[0], StrBuffer, sizeof(StrBuffer) - 1)) {
		mexErrMsgTxt("Unable to read the argument string!\n");
	}


	if (strcmp(StrBuffer, "DataIsReady") == 0) {
		return_code = DataIsReady();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("DataIsReady");
	}
	else if (strcmp(StrBuffer, "RequestLatest3D") == 0) {
		return_code = RequestLatest3D();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RequestLatest3D");
	}
	else if (strcmp(StrBuffer, "RequestNext3D") == 0) {
		return_code = RequestNext3D();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RequestNext3D");
	}
	else if (strcmp(StrBuffer, "RequestLatestTransforms") == 0) {
		return_code = RequestLatestTransforms();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RequestLatestTransforms");
	}
	else if (strcmp(StrBuffer, "RequestNextTransforms") == 0) {
		return_code = RequestNextTransforms();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RequestNextTransforms");
	}
	else if (strcmp(StrBuffer, "OptotrakStopCollection") == 0) {
		return_code = OptotrakStopCollection();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("OptotrakStopCollection");
	}
	else if (strcmp(StrBuffer, "DataGetLatestTransforms") == 0) { // this is the blocking routine for transforms
																  // Ensure we have additional arguments, i.e., start_marker & end_marker
		if (nrhs != 3) {
			mexErrMsgTxt("Two additional arguments (start_marker_no & end_marker_no) must be passed with DataGetLatestTransforms!\n");
		}
		// Make sure the arguments are as expected.
		if (!mxIsDouble(prhs[1])) {
			mexErrMsgTxt("The second argument (start_marker) should be an unsigned integer!\n");
		}
		if (!mxIsDouble(prhs[2])) {
			mexErrMsgTxt("The third argument (end_marker) should be an  unsigned integer!\n");
		}
		unsigned int start_marker = (unsigned int)mxGetScalar(prhs[1]); // from which marker shall we print out 3d values?
		unsigned int end_marker = (unsigned int)mxGetScalar(prhs[2]);   // until which marker shall we do that?
																		// make sure end_marker is larger than start_marker, otherwise set them 1 and 0 respectively, which then results in no 3d values
		if (start_marker > end_marker) {
			start_marker = 1;
			end_marker = 0;
		}
		if (start_marker == 0 || end_marker == 0) {
			start_marker = 1;
			end_marker = 0;
		}

		// Get new data
		return_code = DataGetLatestTransforms(&uFrameNumber, &uElements, &uFlags, &RigidBodyData);
		if (return_code != 0) {
			plhs[1] = mxCreateString("DataGetLatestTransforms");
		}
		else {
			// timestamp of valid DataReceiveLatestTransforms. This is when the sample was registered
			QueryPerformanceCounter(&t1);
			// find out how many markers are in p3dData
			//int uP3elements = sizeof(p3dData) / sizeof(p3dData[0]); // this doesn't work in this case
			// Now we want the 6D data and the 3D data in one row
			unsigned int mat_length = 7 + (uElements * 10) + ((end_marker - start_marker + 1) * 3);
			plhs[1] = mxCreateDoubleMatrix(1, mat_length, mxREAL);
			y = mxGetPr(plhs[1]); // this y points to the output array of the mexFunction
			y[0] = (double)uFrameNumber;
			y[1] = (double)uElements;
			y[2] = (double)uFlags;
			// first, take care of the 6D data
			unsigned int uNextElement = 3; // this is the iterator to run over y
			for (uRigidCnt = 1; uRigidCnt <= uElements; ++uRigidCnt)
			{
				y[uNextElement + 0] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].RigidId;
				y[uNextElement + 1] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].flags;
				// check for invalid transforms
				if (RigidBodyData.pRigidData[uRigidCnt - 1].flags & OPTOTRAK_UNDETERMINED_FLAG) {
					y[uNextElement + 1] = -999;
				}
				if (RigidBodyData.pRigidData[uRigidCnt - 1].flags & OPTOTRAK_RIGID_ERR_MKR_SPREAD) {
					y[uNextElement + 1] = -998;
				}
				y[uNextElement + 2] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].QuaternionError;
				y[uNextElement + 3] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.translation.x;
				y[uNextElement + 4] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.translation.y;
				y[uNextElement + 5] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.translation.z;
				y[uNextElement + 6] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.q0;
				y[uNextElement + 7] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.qx;
				y[uNextElement + 8] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.qy;
				y[uNextElement + 9] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.qz;
				uNextElement = uNextElement + 10;
			}
			// now take care of the 3D data. First we want to know which markers we used
			y[uNextElement] = (double)start_marker;
			y[uNextElement + 1] = (double)end_marker;
			uNextElement = uNextElement + 2;
			// get the 3d values specified by start_marker and end_marker
			if (start_marker <= end_marker) {
				for (ui = (start_marker - 1); ui <= (end_marker - 1); ui++) {
					y[uNextElement] = (double)RigidBodyData.p3dData[ui].x;
					y[uNextElement + 1] = (double)RigidBodyData.p3dData[ui].y;
					y[uNextElement + 2] = (double)RigidBodyData.p3dData[ui].z;
					uNextElement = uNextElement + 3;
				}
			}
			// finally, the timestamps
			y[uNextElement] = (double)t1.QuadPart * 1000 / frequency.QuadPart;
			y[uNextElement + 1] = (double)(frequency.QuadPart);
		}
		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
	}
	else if (strcmp(StrBuffer, "DataReceiveLatestTransforms") == 0) { // this is the non-blocking routine
		// Ensure we have additional arguments, i.e., start_marker & end_marker
		if (nrhs != 3) {
			mexErrMsgTxt("Two additional arguments (start_marker_no & end_marker_no) must be passed with DataReceiveLatestTransforms!\n");
		}
		// Make sure the arguments are as expected.
		if (!mxIsDouble(prhs[1])) {
			mexErrMsgTxt("The second argument (start_marker) should be an unsigned integer!\n");
		}
		if (!mxIsDouble(prhs[2])) {
			mexErrMsgTxt("The third argument (end_marker) should be an  unsigned integer!\n");
		}
		unsigned int start_marker = (unsigned int)mxGetScalar(prhs[1]); // from which marker shall we print out 3d values?
		unsigned int end_marker = (unsigned int)mxGetScalar(prhs[2]);   // until which marker shall we do that?
		// make sure end_marker is larger than start_marker, otherwise set them 1 and 0 respectively, which then results in no 3d values
		if (start_marker > end_marker) {
			start_marker = 1;
			end_marker = 0;
		}
		if (start_marker == 0 || end_marker == 0) {
			start_marker = 1;
			end_marker = 0;
		}
		 
		// Check for new data !!
		return_code = DataIsReady();
		// Receive Data, if it is ready
		if (return_code != 0) {
			return_code = DataReceiveLatestTransforms(&uFrameNumber, &uElements, &uFlags, &RigidBodyData);
			if (return_code != 0) {
				plhs[1] = mxCreateString("DataReceiveLatestTransforms");
			}
			else {
				// timestamp of valid DataReceiveLatestTransforms. This is when the sample was registered
				QueryPerformanceCounter(&t1);
				// find out how many markers are in p3dData
				//int uP3elements = sizeof(p3dData) / sizeof(p3dData[0]); // this doesn't work in this case
				// Now we want the 6D data and the 3D data in one row
				unsigned int mat_length = 7 + (uElements * 10) + ((end_marker-start_marker+1) * 3);
				plhs[1] = mxCreateDoubleMatrix(1, mat_length, mxREAL);
				y = mxGetPr(plhs[1]); // this y points to the output array of the mexFunction
				y[0] = (double)uFrameNumber;
				y[1] = (double)uElements;
				y[2] = (double)uFlags;
				// first, take care of the 6D data
				unsigned int uNextElement = 3; // this is the iterator to run over y
				for (uRigidCnt = 1; uRigidCnt <= uElements; ++uRigidCnt)
				{
					y[uNextElement + 0] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].RigidId;
					y[uNextElement + 1] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].flags;
					// check for invalid transforms
					if (RigidBodyData.pRigidData[uRigidCnt - 1].flags & OPTOTRAK_UNDETERMINED_FLAG) {
						y[uNextElement + 1] = -999;
					}
					if (RigidBodyData.pRigidData[uRigidCnt - 1].flags & OPTOTRAK_RIGID_ERR_MKR_SPREAD) {
						y[uNextElement + 1] = -998;
					}
					y[uNextElement + 2] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].QuaternionError;
					y[uNextElement + 3] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.translation.x;
					y[uNextElement + 4] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.translation.y;
					y[uNextElement + 5] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.translation.z;
					y[uNextElement + 6] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.q0;
					y[uNextElement + 7] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.qx;
					y[uNextElement + 8] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.qy;
					y[uNextElement + 9] = (double)RigidBodyData.pRigidData[uRigidCnt - 1].transformation.quaternion.rotation.qz;
					uNextElement = uNextElement + 10;
				}
				// now take care of the 3D data. First we want to know which markers we used
				y[uNextElement] = (double)start_marker; 
				y[uNextElement+1] = (double)end_marker; 
				uNextElement = uNextElement + 2;
				// get the 3d values specified by start_marker and end_marker
				if (start_marker <= end_marker) {
					for (ui = (start_marker - 1); ui <= (end_marker - 1); ui++) {
						y[uNextElement] = (double)RigidBodyData.p3dData[ui].x;
						y[uNextElement + 1] = (double)RigidBodyData.p3dData[ui].y;
						y[uNextElement + 2] = (double)RigidBodyData.p3dData[ui].z;
						uNextElement = uNextElement + 3;
					}
				}
				// finally, the timestamps
				y[uNextElement] = (double)t1.QuadPart * 1000 / frequency.QuadPart;
				y[uNextElement + 1] = (double)(frequency.QuadPart);
			}
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
		}
		else {
			return_code = -1;
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("DataNotReady");
		}
	}
	else if (strcmp(StrBuffer, "DataReceiveLatest3D") == 0) {
		// Check for new data
		return_code = DataIsReady();
		// Receive Data, if it is ready
		if (return_code != 0) {
			return_code = DataReceiveLatest3D(&uFrameNumber, &uElements, &uFlags, p3dData);
			if (return_code != 0) {
				plhs[1] = mxCreateString("DataReceiveLatest3D");
			}
			else {
				// timestamp of valid DataReceiveLatest3D. This is when the sample was registered
				QueryPerformanceCounter(&t1);
				// Send back frame number, elements, and data in a float array.
				int mat_length = (uElements * 3) + 5;
				plhs[1] = mxCreateDoubleMatrix(1, mat_length, mxREAL);
				y = mxGetPr(plhs[1]);
				y[0] = (double)uFrameNumber;
				y[1] = (double)uElements;
				y[2] = (double)uFlags;

				for (ui = 1; ui <= uElements; ui++) {
					uj = ui * 3;
					y[uj] = (double)p3dData[ui - 1].x;
					y[uj + 1] = (double)p3dData[ui - 1].y;
					y[uj + 2] = (double)p3dData[ui - 1].z;
				}
				y[mat_length - 2] = (double)t1.QuadPart *1000 / frequency.QuadPart;
				y[mat_length - 1] = (double)(frequency.QuadPart);
			}
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
		} 
		else {
			return_code = -1;
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("DataNotReady");
		}
	}
	else if (strcmp(StrBuffer, "DataGetLatest3D") == 0) { 
		// this is a blocking method, you might want to use non-blocking methods instead
		//(float)-3.0E28
		return_code = DataGetLatest3D(&uFrameNumber, &uElements, &uFlags, p3dData);
		if (return_code != 0) {
			plhs[1] = mxCreateString("DataGetLatest3D");
		}
		else {
			// timestamp of valid DataGetLatest3D. This is when the sample was registered
			QueryPerformanceCounter(&t1);
			// 
			unsigned int mat_length = (uElements * 3) + 5;
			plhs[1] = mxCreateDoubleMatrix(1, mat_length, mxREAL);
			y = mxGetPr(plhs[1]);
			y[0] = (double)uFrameNumber;
			y[1] = (double)uElements;
			y[2] = (double)uFlags;

			for (ui = 1; ui <= uElements; ui++) {
				uj = ui * 3;

				y[uj] = (double)p3dData[ui - 1].x;
				y[uj + 1] = (double)p3dData[ui - 1].y;
				y[uj + 2] = (double)p3dData[ui - 1].z;
			}
			y[mat_length - 2] = (double)t1.QuadPart * 1000 / frequency.QuadPart;
			y[mat_length - 1] = (double)(frequency.QuadPart);
		}
		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);	
	}
	else if (strcmp(StrBuffer, "TransputerDetermineSystemCfg") == 0) {
		// This will beep twice.
		return_code = TransputerLoadSystem("system");

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("TransputerDetermineSystemCfg");
	}
	else if (strcmp(StrBuffer, "RigidBodyDelete") == 0) {
		// Ensure we an additional argument, i.e., int nRigidBodyId
		if (nrhs != 2) {
			mexErrMsgTxt("One additional argument (nRigidBodyId) must be passed with RigidBodyDelete!\n");
		}
		// Make sure the arguments are as expected.
		if (!mxIsDouble(prhs[1])) {
			mexErrMsgTxt("The second argument (nRigidBodyId) should be an unsigned integer!\n");
		}
		// get the rigid body identifier
		ui = (unsigned int)mxGetScalar(prhs[1]);	// identifier to be associated with the rigid body
		// delete it
		return_code = RigidBodyDelete(ui);

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RigidBodyDelete");
		// check whether that worked
		if (return_code != 0) {
			TransputerShutdownSystem();
			return;
		}
	}
	else if (strcmp(StrBuffer, "RigidBodyAddShelf") == 0) { // This is for testing purposes
		// definition of the shelf
		static Position3d
			dtShelf[3] =
		{
			{ -0.3109F, -0.1974F, -0.0000F },
			{ -782.4679F,  0.1973F, 0.0000F },
			{ 0.3109F, -496.7630F, -0.0000F }
		};
		// here we add the definition of the shelf.
		return_code = RigidBodyAdd(
			0,					/* ID associated with this rigid body. */
			1,                      /* First marker in the rigid body. */
			3,                      /* Number of markers in the rigid body. */
			(float *)dtShelf,    /* 3D coords for each marker in the body. */
			NULL,                   /* no normals for this rigid body. */
			OPTOTRAK_QUATERN_RIGID_FLAG);

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RigidBodyAddShelf");
		// check whether that worked
		if (return_code != 0) {
			TransputerShutdownSystem();
			return;
		}
	}
	else if (strcmp(StrBuffer, "RigidBodyAddFromFile") == 0) {
		// Ensure we have additional arguments, i.e., nRigidBodyId, nStartMarker, pszRigFile
		if (nrhs != 4) {
			mexErrMsgTxt("Three additional arguments (nRigidBodyId, nStartMarker, pszRigFile) must be passed with RigidBodyAddFromFile!\n");
		}
		// Make sure the arguments are as expected.
		if (!mxIsDouble(prhs[1])) {
			mexErrMsgTxt("The second argument (nRigidBodyId) should be an unsigned integer!\n");
		}
		if (!mxIsDouble(prhs[2])) {
			mexErrMsgTxt("The third argument (nStartMarker) should be a double!\n");
		}
		if (!mxIsChar(prhs[3])) {
			mexErrMsgTxt("The 4th argument (pszRigFile) should be a string!\n");
		}
		// Read the second and third arguments into unsigned integers.
		ui = (unsigned int)mxGetScalar(prhs[1]);	// identifier to be associated with the rigid body
		int start_marker = (unsigned int)mxGetScalar(prhs[2]);					// start marker
		// the third argument is the filename of the RIG
		if (mxGetString(prhs[3], StrBuffer2, sizeof(StrBuffer2) - 1)) {
			mexErrMsgTxt("Unable to read pszRigFile filename argument string!\n");
		}

		// Now add the RigidBody
		return_code = RigidBodyAddFromFile(
			ui,  /* ID associated with this rigid body.*/
			start_marker,				/* First marker in the rigid body.*/
			StrBuffer2,					/* name of RIG file containing rigid body coordinates.*/
			OPTOTRAK_QUATERN_RIGID_FLAG | OPTOTRAK_RETURN_QUATERN_FLAG | OPTOTRAK_UNDETERMINED_FLAG | OPTOTRAK_RIGID_ERR_MKR_SPREAD);
			/* Flags at last. */ 

		Sleep(1);

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("RigidBodyAddFromFile");
		// check whether that worked
		if (return_code != 0) {
			TransputerShutdownSystem();
			return;
		}

	}
	else if (strcmp(StrBuffer, "TransputerLoadSystem") == 0) {
		// Ensure we have a four additional arguments.
		if (nrhs != 7) {
			mexErrMsgTxt("Six additional arguments (#markers on port 1, #markers on port 2, Hz, time, cam filename, external_clock_yes) must be passed with TransputerLoadSystem!\n");
		}

		// Make sure the arguments are as expected.
		if (!mxIsDouble(prhs[1])) {
			mexErrMsgTxt("The second argument (num oprotrak markers on port 1) should be an unsigned integer!\n");
		}
		if (!mxIsDouble(prhs[2])) {
			mexErrMsgTxt("The third argument (num oprotrak markers on port 2) should be an unsigned integer!\n");
		}
		if (!mxIsDouble(prhs[3])) {
			mexErrMsgTxt("The 4th argument (collection frequency) should be a double!\n");
		}
		if (!mxIsDouble(prhs[4])) {
			mexErrMsgTxt("The 5th argument (collection duration) should be a double!\n");
		}
		if (!mxIsChar(prhs[5])) {
			mexErrMsgTxt("The 6th argument (cam filename) should be a string!\n");
		}
		if (!mxIsDouble(prhs[6])) {
			mexErrMsgTxt("The 7th argument (external_clock_yes) should be an unsigned integer, either 0 or 1!\n");
		}

		// Read the second and third arguments into unsigned integers.
		markers_on_port_1 = (unsigned int)mxGetScalar(prhs[1]);	// number of Optotrak markers on SCU port 1
		markers_on_port_2 = (unsigned int)mxGetScalar(prhs[2]);	// number of Optotrak markers on SCU port 2
		dk = mxGetScalar(prhs[3]);					// collection frequency
		dl = mxGetScalar(prhs[4]);					// collection duration (s)
		unsigned short external_clock_yes = (unsigned short)mxGetScalar(prhs[6]);	// shall a frame be clocked externally? 
		if (external_clock_yes > 1 || external_clock_yes < 0) { // this value should be either 0 or 1. Default: 0
			external_clock_yes = 0;
		}

		if (mxGetString(prhs[5], StrBuffer2, sizeof(StrBuffer2) - 1)) {
			mexErrMsgTxt("Unable to read fifth cam filename argument string!\n");
		}

		return_code = TransputerLoadSystem("system");	// This will beep twice.
		if (return_code != 0) {
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("TransputerLoadSystem");
			TransputerShutdownSystem();
			return;
		}
		Sleep(1);

		return_code = TransputerInitializeSystem(OPTO_LOG_ERRORS_FLAG | OPTO_LOG_MESSAGES_FLAG);
		if (return_code != 0) {
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			//if (OptotrakGetErrorString(szNDErrorString, MAX_ERROR_STRING_LENGTH + 1) == 0)
			//{
			//	plhs[1] = szNDErrorString;
			//}
			plhs[1] = mxCreateString("TransputerInitializeSystem");
			TransputerShutdownSystem();
			return;
		}

		// Here, we set the processing flags
		return_code = OptotrakSetProcessingFlags(OPTO_LIB_POLL_REAL_DATA | OPTO_CONVERT_ON_HOST | OPTO_RIGID_ON_HOST); // 
		if (return_code != 0) {
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("OptotrakSetProcessingFlags");
			TransputerShutdownSystem();
			return;
		}

		return_code = OptotrakLoadCameraParameters(StrBuffer2);
		if (return_code != 0) {
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("OptotrakLoadCameraParameters");
			TransputerShutdownSystem();
			return;
		}

		return_code = OptotrakSetStroberPortTable(markers_on_port_1, markers_on_port_2, 0, 0);	// Number of markers connected to each port
		if (return_code != 0) {
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("OptotrakSetStroberPortTable");
			TransputerShutdownSystem();
			return;
		}

		
		if (external_clock_yes == 0) {
			return_code = OptotrakSetupCollection(
				markers_on_port_1 + markers_on_port_2,	// Number of markers in the collection
				(float)dk,				// Frequency to collect data frames at
				(float)4600.0,			// Marker frequency for marker maximum on-time
				30,						// Dynamic or Static Threshold value to use
				160,					// Minimum gain code amplification to use
				0,						// Stream mode for the data buffers
				(float)0.45,			// Marker Duty Cycle to use
				(float)11.0,				// Voltage to use when turning on markers
				(float)dl,				// Number of seconds of data to collect
				(float)0.0,				// Number of seconds to pre-trigger data by, not suppoted and must be 0
				OPTOTRAK_NO_FIRE_MARKERS_FLAG | OPTOTRAK_BUFFER_RAW_FLAG);	// OPTOTRAK_GET_NEXT_FRAME_FLAG often used with realtime data
		}
		else { // this is the collection we start, if triggers are set externally. It is the same but sets the flags at the end
			return_code = OptotrakSetupCollection(
				markers_on_port_1 + markers_on_port_2,	// Number of markers in the collection
				(float)dk,				// Frequency to collect data frames at
				(float)4600.0,			// Marker frequency for marker maximum on-time
				30,						// Dynamic or Static Threshold value to use
				160,					// Minimum gain code amplification to use
				0,						// Stream mode for the data buffers
				(float)0.45,			// Marker Duty Cycle to use
				(float)11.0,				// Voltage to use when turning on markers
				(float)dl,				// Number of seconds of data to collect
				(float)0.0,				// Number of seconds to pre-trigger data by, not suppoted and must be 0
				OPTOTRAK_EXTERNAL_CLOCK_FLAG | OPTOTRAK_EXTERNAL_TRIGGER_FLAG | OPTOTRAK_NO_FIRE_MARKERS_FLAG | OPTOTRAK_BUFFER_RAW_FLAG);
		}
		if (return_code != 0) {
			nlhs = 2;
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateString("OptotrakSetupCollection");
			TransputerShutdownSystem();
			return;
		}

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("OptotrakSetupCollection");
	}
	else if (strcmp(StrBuffer, "TransputerShutdownSystem") == 0) {
		return_code = TransputerShutdownSystem();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("TransputerShutdownSystem");
	}
	else if (strcmp(StrBuffer, "OptotrakActivateMarkers") == 0) {
		return_code = OptotrakActivateMarkers();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("OptotrakActivateMarkers ");
	}
	else if (strcmp(StrBuffer, "OptotrakDeActivateMarkers") == 0) {
		return_code = OptotrakDeActivateMarkers();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("OptotrakDeActivateMarkers ");
	}
	else if (strcmp(StrBuffer, "DataBufferInitializeFile") == 0) {
		// Second argument example: ../data/raw/
		// Third argument example: 001.P1
		// The program will append R#

		// Ensure we have a second and third string argument with the filename (path, part of filename).
		if (nrhs != 3) {
			mexErrMsgTxt("A second and third string arguments must also be passed with DataBufferInitializeFile!\n");
		}

		// Make sure the second and third arguments are strings.
		if (!mxIsChar(prhs[1])) {
			mexErrMsgTxt("The second filepath argument should be a string!\n");
		}
		if (!mxIsChar(prhs[2])) {
			mexErrMsgTxt("The third part-filename argument should be a string!\n");
		}

		// Read the strings into StrBuffers.
		if (mxGetString(prhs[1], StrBuffer2, sizeof(StrBuffer2) - 1)) {
			mexErrMsgTxt("Unable to read second filepath argument string!\n");
		}
		if (mxGetString(prhs[2], StrBuffer3, sizeof(StrBuffer3) - 1)) {
			mexErrMsgTxt("Unable to read third part-filename argument string!\n");
		}

		filename_input[0] = '\0';
		strcat_s(filename_input, StrBuffer2);
		strcat_s(filename_input, "R#");
		strcat_s(filename_input, StrBuffer3);
		return_code = DataBufferInitializeFile(OPTOTRAK, filename_input);

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("DataBufferInitializeFile ");
	}
	else if (strcmp(StrBuffer, "DataBufferSpoolData") == 0) {
		return_code = DataBufferSpoolData(&uSpoolStatus);

		nlhs = 2;
		if (return_code != 0 || uSpoolStatus != 0) {
			plhs[0] = mxCreateDoubleScalar(-1);
			if (return_code != 0) {
				plhs[1] = mxCreateString("DataBufferSpoolData");
			}
			else {
				plhs[1] = mxCreateString("uSpoolStatus");
			}
		}
		else {
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateDoubleScalar(uSpoolStatus);
		}
	}
	else if (strcmp(StrBuffer, "DataBufferStart") == 0) {
		return_code = DataBufferStart();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("DataBufferStart");
	}
	else if (strcmp(StrBuffer, "DataBufferWriteData") == 0) {
		// Returns -1 and DataBufferWriteData || uSpoolStatus on error.
		// Returns 0 and uSpoolComplete on success.	
		return_code = DataBufferWriteData(&uRealtimeDataReady, &uSpoolComplete, &uSpoolStatus, NULL);

		nlhs = 2;
		if (return_code != 0 || uSpoolStatus != 0) {
			plhs[0] = mxCreateDoubleScalar(-1);
			if (return_code != 0) {
				plhs[1] = mxCreateString("DataBufferWriteData");
			}
			else {
				plhs[1] = mxCreateString("uSpoolStatus");
			}
		}
		else {
			plhs[0] = mxCreateDoubleScalar(return_code);
			plhs[1] = mxCreateDoubleScalar(uSpoolComplete);
		}
	}
	else if (strcmp(StrBuffer, "DataBufferStop") == 0) {
		return_code = DataBufferStop();

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("DataBufferStop");
	}
	else if (strcmp(StrBuffer, "FileConvert") == 0) {
		// Ensure we have a second and third string argument with the filename (path, part of filename).
		if (nrhs != 3) {
			mexErrMsgTxt("A second and third string arguments must also be passed with DataBufferInitializeFile!\n");
		}

		// Make sure the second and third arguments are strings.
		if (!mxIsChar(prhs[1])) {
			mexErrMsgTxt("The second filepath argument should be a string!\n");
		}
		if (!mxIsChar(prhs[2])) {
			mexErrMsgTxt("The third part-filename argument should be a string!\n");
		}

		// Read the strings into StrBuffers.
		if (mxGetString(prhs[1], StrBuffer2, sizeof(StrBuffer2) - 1)) {
			mexErrMsgTxt("Unable to read second filepath argument string!\n");
		}
		if (mxGetString(prhs[2], StrBuffer3, sizeof(StrBuffer3) - 1)) {
			mexErrMsgTxt("Unable to read third part-filename argument string!\n");
		}

		filename_input[0] = '\0';
		filename_output[0] = '\0';
		strcat_s(filename_input, StrBuffer2);
		strcat_s(filename_output, StrBuffer2);
		strcat_s(filename_input, "R#");
		strcat_s(filename_output, "C#");
		strcat_s(filename_input, StrBuffer3);
		strcat_s(filename_output, StrBuffer3);
		return_code = FileConvert(filename_input, filename_output, OPTOTRAK_RAW);

		nlhs = 2;
		plhs[0] = mxCreateDoubleScalar(return_code);
		plhs[1] = mxCreateString("FileConvert OPTOTRAK");
		//OptotrakGetErrorString(szNDErrorString, MAX_ERROR_STRING_LENGTH + 1);
		//mexPrintf("API Error: %s", szNDErrorString);	% printed weird text...
	}
	else {
		mexErrMsgTxt("A command was not found for that string argument!\n");
	}
	// also return timestamp at start and at end of function#
	QueryPerformanceCounter(&tend);
	plhs[2] = mxCreateDoubleScalar((double)tstart.QuadPart*1000 / frequency.QuadPart);
	plhs[3] = mxCreateDoubleScalar((double)tend.QuadPart * 1000 / frequency.QuadPart);
}