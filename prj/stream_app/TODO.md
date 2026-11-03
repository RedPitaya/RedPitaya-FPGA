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

## The channels overflow apart in the continuous mode

In the block mode a word lost by any channel makes every channel drop the series and start the
buffer being filled again (`dma_blocks2_tb`). In the continuous mode every channel still drops
on its own (whole bursts, so the data stays in order): with one port stalling, the buffers of one
index hold different times in the channels (their lost counters differ; `irq_tb` KNOWN). A common
drop there needs a common burst decision across the channels.

## 250-12: two channels in the block mode lose a quarter of the series

rp34, `streamtest.py` `test_trigger` with CH1 and CH2 (decimation 32, a 2 KB buffer per trigger,
3815 triggers/s): ~1550 of ~6400 series dropped per 2 s run, with CH1 alone 2..20. The drops are
counted and the channels stay in step; where the time goes (the server releasing buffers late,
the HP ports) is to be looked at.
