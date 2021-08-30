# Memory Base 128

## Description
The **NEC Memory Base 128** (mb128 for short) is an external **PC-Engine** RAM backup unit that plugs between the joypad port and the joypad itself. It can stores up to **128 KB**, which is **64** times more than the standard backup units (**Tennokoe 2** or **Duo** internal BRAM). Just like the **Tennokoe 2**, the **mb128** needs to be powered by external batteries (4 AA) in order to retain data. It is built around the **MSM6389C** from **OKI Semiconductor**, a **1048576 x 1bit** solid-state data register.
This means that data is transferred **1 bit at a time**.

Note that **Koei** released a similar device (if not a clone), the **Save Kun**.

## Basic operations
As the **mb128** is plugged into the joyport, communication is done through the joypad control port (**$1000**).
Without further ado, here is how to send a bit to the **mb128**. At this point the bit may not be stored. There is a bit of protocol to respect before getting
anything written on the **MSM6389C** (more on this later).
In the following routine the A register holds the bit (0 or 1) to be sent. If
you have ever looked at a joypad routine, you will recognize the classic delays
delay used in many games and in **MagicKit**.
```
mb128_send_bit:
    and #$01
    sta joyport     ; CLR=0 SEL=bit to send (let's call it b)
    pha             ; short delay
    pla
    nop
    ora #$02 
    sta joyport     ; CLR=1 SEL=b
    pha             ; long delay
    pla
    pha
    pla
    pha
    pla
    and #$01
    sta joyport     ; CLR=0 SEL=b
    pha             ; short delay
    pla
    nop
    rts
```

A byte is transferred by sending each bit separately starting from bit **0** to bit **7**. This can easily be done by repeatedly shifting the value to the right and sending the carry flag to the **mb128**. This can be translated in the following C-like pseudo-code.
```c
void mb128_send_byte(byte a) {
    for(int i=0; i<8; i++) {
        mb128_send_bit( a & 1 );
        a >>= 1;
    }
}
```
Reading a bit is performed in a similar fashion. The assembly routine looks like this :
```
mb128_read_bit:
    stz joyport     ; CLR=0 SEL=0
    pha             ; short delay
    pla
    nop
    lda #$02
    sta joyport     ; CLR=1 SEL=0
    pha             ; short delay
    pla
    nop
    lda joyport     ; read joypad part
    stz joyport     ; CLR=0 SEL=0
    pha             ; short delay
    pla
    and #$01        ; we only need the first bit
    rts
```

Reading a byte is done just like its counterpart. A byte is read by performing
**8** consecutive bit read and pushing the bit using left shift.
```c
byte mb128_read_byte() {
    byte acc = 0;
    for(int i=0; i<8; i++) {
        acc <<= 1;
        acc |= mb128_read_bit();
    }
    return acc;
}
```

## Detection
The following sequence let you detect the presence of a **mb128**.
```c
bool mb128_detect() {
    for(int i=0; i<4; i++) {            // we'll make 4 attempts
        byte ret;
        
        mb128_send_byte( 0xA8 );
        mb128_send_bit( 0 );
        
        ret = (joyport & 0x05) << 4;
        
        mb128_send_bit(1);

        ret |= joyport & 0x05;

        if(ret == 0x04) {               // we detected a mb128
            return true;
        }
    }
    // detection failed
    mb128_send_bit(0);
    mb128_send_bit(0);
    mb128_send_bit(0);

    return false;
}
```
A **mb128** is plugged to the joyport if **res** is equal to **4**. Some games make **3** attempts before calling it quits

## Boot 🚧

At startup just after detection, a special sequence is performed. It can be viewed as a boot/reset sequence.
```c
mb128_boot:
mb128_send_bit( 1 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );

mb128_send_byte( 0x00 );
mb128_send_byte( 0x01 );
mb128_send_byte( 0x00 );

mb128_send_bit( 0 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );

mb128_read_bit();

mb128_send_bit( 0 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );
```
Once `mb128_detect` and `mb128_boot` are performed, you can safely read or write data to the **mb128** storage.

## Sector read/write 🚧
All games studied store or retrieve data by blocs of **512** bytes. A bloc is called a sector.
The first thing to do is to tell the **mb128 **which sector is being processed. As the **mb128** can stored up to **128KB**, there are **256** (`0x100`) available sectors. The sequence sent is similar to the one sent for a boot sequence (`mb128_boot`).
```c
mb128_sector_addr:
mb128_send_bit( 1 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );

mb128_send_byte( sector_id );
mb128_send_byte( 0x00 );
mb128_send_byte( 0x10 );

mb128_send_bit( 0 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );
mb128_send_bit( 0 );
```
Once the sector address is set byte can be read or written using `mb128_read` or `mb128_write`. A standard multi-sector read routine looks like this :
```c
mb128_read_sectors:
for( b=0; b<sector_count; b++ ) {
    if( mb128_detect() == success ) {
        mb128_sector_addr( sector + b );
        for( i=0; i<512; i++ ) {
            out[i] = mb128_read_byte();
        }
    }
}
```
And similarly for a multi-sector write we have : 
```c
mb128_write_sectors:
for( b=0; b<sector_count; b++ ) {
    if( mb128_detect() == success ) {
        mb128_sector_addr( sector + b );
        for( i=0; i<512; i++ ) {
            mb128_send_byte( in[i] );
        }
    }
}
```
## Header format 🚧
The first **2** sectors (**1024** bytes) of the **mb128** holds what can be describe as an entry list. Each entry is **16** bytes long. This means that the those sector can hold **64** entries.
The first entry contains the header. It is organized as follow :

 offset | purpose 
 -:|:-
 0 | CRC (lsb)
 1 | CRC (msb)
 2 | Used sector count (lsb)
 3 | Used sector count (msb)
 4 | Header string `ﾒﾓﾘﾍﾞｰｽ128\x0000`
 . |
 f | Last header string char (0x00)

The Header **CRC** is the sum of the bytes **0x02** to **0x3ff**. Some games (**Shin Megami Tensei** for example) keep bytes **2** and **3** at **zero**.

Next comes the savegame entries. 

 offset | purpose 
-:|:-
 0 | sector number
 1 | sector count
 2 | unknown (0x00)
 3 | unknown (0x02)
 4 | CRC (lsb)
 5 | CRC (msb)
 6 | unknown (0x00)
 7 | unknown (0x00)
 8 | entry name
 . |
 f | Last entry name char (0x00)

The first **2** bytes tell where the data is stored (sector number) and how many sectors are used. The meaning of bytes **2**, **3**, **4** and **5** is unknown. None of the game studied are using them, but they all store the same values. That is **0x00** and **0x02** for bytes **2** and **3**, and **0x00** for both bytes **6** and **7**. 

The **CRC** is sum of the stored bytes. This can be translated in the following 
pseudo-C code.
```c
u8  out[ sector_count * 512 ]; 
u16 crc = 0;

mb128_read( sector, sector_count );

for( i=0; i<sector_count; i++ ) {
    for( j=0; j<512; j++ ) {
        crc += out[ (i*512) + j ];
    }
}  
```
The entry name is a **8** bytes string. It is supposed to be unique allowing games to retrieve their data.
Here are some examples :
  * `ﾕｳｼｬM128` for **Tadaima Yusha Boshuuchuu**
  * `MT0     `, `MT1     `, ... for **Shin Megami Tensei**

**Shin Megami Tensei** allows the player to have up to **10** save-states. Where **Tadaima Yusha Boshuuchuu** only allows **1** save-state.

The format of the data stored is not standardized. This means that they are
game dependent. For example, it seems that **Tadaima Yusha Boshuuchuu** is using the **mb128** as an extra **BRAM**. On the other hand, **Shin Megami Tensei** has its own internal format.

## Thanks 🚧


## Contact
mooz at blockos dot org

## License
This document is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0).
[![License: CC BY-NC-SA 4.0](https://licensebuttons.net/l/by-nc-sa/4.0/80x15.png)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

