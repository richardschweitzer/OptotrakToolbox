Some script to run on the Optotrak Host PC to play around with. Please note: Not all of them are commented, none of them is perfect, most of them are work in progress.

Of course, you need Matlab_to_Optotrak().

Easy optotrak sampling: test_opto_sampling.m

Optotrak sampling with buffering: collect_a_trial_2.m (non-blocking version), collect_a_trial_2_blocking.m (blocking version), collect_a_trial_2_bufferAtEnd.m (non-blocking version, but with blocked buffer retrieval at the end of the script).

Sampling with the possibility to retrieve transforms and to trigger the production of a frame externally: test_opto_sampling_transforms_external.m

Definitions of rigid bodies can be found here: some_rigid_bodies.zip

Some camera alignments (i.e., different coordinate systems) can be found here: some_cam_alignments.zip 
