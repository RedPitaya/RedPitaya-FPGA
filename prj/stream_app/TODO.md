# stream_app: open defects

Found with the streaming tests of redpitaya-regress (`streamtest.py` `test_trigger`, 2026-11-02,
bitstreams of d12ee3e) and the unit benches in `tbn/unit`.

## The full flag of a buffer comes before its last burst is written

`buf1_full` / `buf2_full` (and the buffer switch with its interrupt) are set when the request
address reaches the last burst of the buffer, before the data of that burst is in the FIFO. In
`dma_blocks_tb` the last word reaches the memory up to 510 clocks after the flag at decimation 8
(one burst: 16 words of 4 samples x decimation clocks). A reader that takes the buffer at once
may read up to 64 old samples at its end; at a high decimation that is a long time. Not seen on
the boards yet (the server reads the buffers later through its ring). Reported as KNOWN by
`dma_blocks_tb`.

## dma_ts_tb fails in its run with gaps and overflows, depending on the seed

The last run of `tbn/unit/dma_ts_tb` (gaps and late ACKs, continuous mode) reports a buffer whose
wait is not the dropped slots before it and whose lost count is not the gap in the data (2 to 4
errors). At HEAD before the block mode fix it fails with 3 of the seeds 1..4 (`xsim -sv_seed`) and
passes with the default one; with the fix the default seed fails too (another random sequence: a
new process in the DMA). The lost/wait accounting after an overflow in the middle of a gap is to
be looked at.

## 250-12: lost scope interrupts at about 3815 buffers/s

On the 250-12 (`rtl_250`, stream at 250 MHz, DMA at 125 MHz) `dma_sts` reads both buffers full
(0x17), the triggers go on, but no interrupt comes; the streaming server waits for its 1 s poll
timeout. A continuous stream of 2 KB buffers at decimation 64 shows it as well (2 missed
interrupts in 4 s); rp33 (`rtl`) and rp31 (`rtl_250` at 125 MHz) lose none at 3815 and 7630
buffers/s. The interrupt is set on a buffer switch (`req_buf_addr_sel` edge) and only when the
other channel is not behind (`buf_sel_in`); `next_buf_full` is cleared by the ACK of either
buffer. Not reproduced in a bench yet.
