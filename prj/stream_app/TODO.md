# stream_app: open defects

Found with the streaming tests of redpitaya-regress (`streamtest.py` `test_trigger`, 2026-11-02,
bitstreams of d12ee3e) and the unit benches in `tbn/unit`.

## Scope DMA buffers out of step with the series after an overflow (block mode)

In the block mode the acquisition (`rp_oscilloscope/osc_aquire.v`) counts a series by the
samples it sends (`blk_rem`); the DMA (`rp_dma_s2mm_ctrl.v`) closes a buffer by its address, i.e.
by the words it writes. When the next buffer is not free at the start of a series, the DMA resets
its FIFO and drops the first L samples (`FIFO_RST`, `WAIT_BUF_FULL`, `fifo_dis`); the series still
ends after its length, the buffer gets only the rest and is filled up by the next series. From
then on every buffer holds the end of one series and the start of the next (offset L, for good).
The data and the lost/wait counts stay right; a client that takes a buffer for a series does not.

- Seen on rp31 (125-14 TI, `rtl_250`, L = 524) and rp38 (125-14 Gen2, `rtl`, L = 4).
- Reproduced by `tbn/unit/dma_blocks_tb.sv` (rtl variant), reported there as KNOWN.
- osc_aquire raises `tlast` only at the end of a normal mode capture; the DMA sees the end of a
  series only as `s_axis_flush` (armed) and the drop strobes.
- Possible fix: in the block mode, once a word of a series is lost (rejected by the FIFO, or the
  FIFO reset while a series runs), drop the rest of the series up to the next arm; the next
  series then starts at the start of the free buffer. Needs a block mode input to the DMA (in the
  continuous mode there is no series end). A loss in the middle of a buffer (the FIFO full under
  AXI stalls) also needs the write address back at the start of the buffer. In rtl, rtl_250 and
  rtl_4ch.

## The full flag of a buffer comes before its last burst is written

`buf1_full` / `buf2_full` (and the buffer switch with its interrupt) are set when the request
address reaches the last burst of the buffer, before the data of that burst is in the FIFO. In
`dma_blocks_tb` the last word reaches the memory up to 510 clocks after the flag at decimation 8
(one burst: 16 words of 4 samples x decimation clocks). A reader that takes the buffer at once
may read up to 64 old samples at its end; at a high decimation that is a long time. Not seen on
the boards yet (the server reads the buffers later through its ring). Reported as KNOWN by
`dma_blocks_tb`.

## 250-12: lost scope interrupts at about 3815 buffers/s

On the 250-12 (`rtl_250`, stream at 250 MHz, DMA at 125 MHz) `dma_sts` reads both buffers full
(0x17), the triggers go on, but no interrupt comes; the streaming server waits for its 1 s poll
timeout. A continuous stream of 2 KB buffers at decimation 64 shows it as well (2 missed
interrupts in 4 s); rp33 (`rtl`) and rp31 (`rtl_250` at 125 MHz) lose none at 3815 and 7630
buffers/s. The interrupt is set on a buffer switch (`req_buf_addr_sel` edge) and only when the
other channel is not behind (`buf_sel_in`); `next_buf_full` is cleared by the ACK of either
buffer. Not reproduced in a bench yet.
