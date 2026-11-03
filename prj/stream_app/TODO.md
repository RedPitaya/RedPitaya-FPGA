# stream_app: open defects

Found with the streaming tests of redpitaya-regress (`streamtest.py` `test_trigger`, 2026-11-02,
bitstreams of d12ee3e) and the unit benches in `tbn/unit`.

## dma_ts_tb fails in its run with gaps and overflows, depending on the seed

The last run of `tbn/unit/dma_ts_tb` (gaps and late ACKs, continuous mode) reports a buffer whose
wait is not the dropped slots before it and whose lost count is not the gap in the data (2 to 4
errors). At HEAD before the block mode fix it fails with 3 of the seeds 1..4 (`xsim -sv_seed`) and
passes with the default one; with the fix the default seed fails too (another random sequence: a
new process in the DMA). The lost/wait accounting after an overflow in the middle of a gap is to
be looked at.

## The overflow bits of 0x54 are of CH1

The full flags of 0x54 are of all channels since the 250-12 fix (a buffer is taken when every
channel has written it), the overflow bits and the lost counter the server reads stay of CH1.
An overflow of another channel alone shows only in its lost counter (0x230 ..).

## The channels overflow apart (the 250-12 trigger test)

Every channel has its own DMA and decides an overflow alone, when it needs its next buffer
(next_buf_full) or, in the block mode, drops the rest of its series. A channel behind the other
(its HP port loaded, the 250-12 at 3815 buffers/s) asks for the next buffer later: a release in
between makes CH1 drop a series CH2 writes, and from then on the channels are a buffer apart for
good (CH1 B1 / CH2 B0 in the write pointers of rp34). With the full flags of 0x54 of all
channels the software holds every buffer a period longer while they are apart, and CH1
overflows on every other series (rp34, 2026-11-03: no stall any more, 2300..5000 of ~7000 series
with a loss; before the 0x54 change the software released CH2 buffers unwritten and stalled
instead). `irq_tb` shows it as KNOWN with a stalling CH2 port.

To fix: one overflow decision for all channels. In the block mode at the start of a series (a
common event): the series goes into the next buffer when it is free in every channel, else every
channel drops the whole series; in the continuous mode the drop of one channel made common
(every channel drops the same samples).
