// Copyright (c) 2022, Tri Dao.

#include "fmha_bwd_with_mask_bias_launch_template.h"

bool run_fmha_bwd_with_mask_bias_hdim64(FMHA_dgrad_params &params, cudaStream_t stream) {
    bool status = true;
    auto dprops = GetDeviceProperties(-1);
    FP16_SWITCH(params.is_bf16, ([&] {
        if( params.seqlen_k == 128 ) {
            using Kernel_traits = FMHA_kernel_traits<128, 64, 16, 1, 8, 0x08u, elem_type>;
            status = run_fmha_dgrad_fp16_sm80_loop_<Kernel_traits>(params, stream);
        } else if( params.seqlen_k >= 256 ) {
            if (dprops->major == 8 && dprops->minor == 0) {
                // Don't share smem for K & V, and don't keep V in registers
                // This speeds things up by 2-3% by avoiding register spills, but it
                // uses more shared memory, which is fine on A100 but not other GPUs.
                // For other GPUs, we keep V in registers.
                using Kernel_traits = FMHA_kernel_traits<256, 64, 16, 1, 8, 0x100u, elem_type>;
                status = run_fmha_dgrad_fp16_sm80_loop_<Kernel_traits>(params, stream);
            } else if (dprops->major == 8 && dprops->minor > 0) {
                using Kernel_traits = FMHA_kernel_traits<256, 64, 16, 1, 8, 0x08u, elem_type>;
                status = run_fmha_dgrad_fp16_sm80_loop_<Kernel_traits>(params, stream);
            } else if (dprops->major == 7 && dprops->minor == 5) {
                using Kernel_traits = FMHA_kernel_traits<128, 64, 16, 1, 8, 0x08u, elem_type>;
                status = run_fmha_dgrad_fp16_sm80_loop_<Kernel_traits>(params, stream);
            }
        }
    }));
    return status;
}
