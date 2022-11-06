# Memory Base 128

## Description
The **NEC Memory Base 128** is an external **PC-Engine** RAM backup unit that plugs between the joypad port and the joypad itself. It can stores up to **128 KB**, which is **64** times more than the standard backup units (**Tennokoe 2** or **Duo** internal BRAM). Just like the **Tennokoe 2**, the **mb128** needs to be powered by external batteries (4 AA) in order to retain data. It is built around the **MSM6389C** from **OKI Semiconductor**, a **1048576 x 1bit** solid-state data register.
This means that data is transferred **1 bit at a time**.

**Koei** released a similar device (if not a clone), the **Save Kun**.

## Compatibility List
  * A. III - Takin' the A Train [ADCD3001]
  * Atlas Renaissance Voyage [ADCD4002]
  * Bishoujo Senshi Sailor Moon Collection [BACD4004]
  * Brandish [HECD4007]
  * Eikan ha Kimini - Koukou Yakyuu Zenkoku Taikai [ADCD4003]
  * Emerald Dragon [HECD3005]
  * Fire Pro Jyoshi - Dome Choujyo Taisen [HMCD4008]
  * Ganchouhishi - Aoki Ookami to Shiroki Mejika [KOCD3004]
  * Linda Cube [HECD5023]
  * Magicoal [HECD3002]
  * Mahojng Sword Princess Quest Gaiden [NXCD4031]
  * Nobunaga no Yabou - Bushou Fuuunroku [KOCD2001]
  * Nobunaga no Yabou Zenkokuban [KOCD3005]
  * Popful Mail [HECD4011]
  * Princess Maker 2 [HECD5020]
  * Private Eye Dol [HECD5019]
  * Sankokushi III [KOCD3003]
  * Shin Megami Tensei [ATCD3006]
  * Super Mahjong Taikai [KOCD2002]
  * Super Real Mahjong P II - P III Custom [NXCD4030]
  * Super Real Mahjong P V Custom [NXCD5032]
  * Tadaima Yuusha Boshuuchuu [HMCD3006]
  * Vasteel 2 [HMCD4007]

## Basic operations
As the Memory Base 128 is plugged into the joyport, communication is done through the joypad control port (**$1000**). 

Without further ado, here is how to send a bit to the Memory Base 128. At this point the bit may not be stored. There is a bit of protocol to respect before getting anything written on the **MSM6389C** (more on this later).
In the following routine the A register holds the bit (0 or 1) to be sent. If you have ever looked at a joypad routine, you will recognize the classic delays used in many games and in **MagicKit**.
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

A byte is transferred by sending each bit separately starting from bit **0** to bit **7**. This can easily be done by repeatedly shifting the value to the right and sending the carry flag to the Memory Base 128. This can be translated in the following C-like pseudo-code.
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

Reading a byte is done just like its counterpart. A byte is read by performing **8** consecutive bit reads.
```c
byte mb128_read_byte() {
    byte acc = 0;
    for(int i=0; i<8; i++) {
        acc |= mb128_read_bit() << i;
    }
    return acc;
}
```

## Init
At startup, the Memory Base 128 is in pass-through or joypad mode. The bit sequence **00010101** (or **A8** in hex) must be sent in order to switch mode and access the Memory Base 128 storage. Once it is sent, 2 **ident** bits must be sent and read back from the joyport. The value read will determine if the Memory Base 128 switch was successful.
Note that when the Memory Base 128 is active, the joypad (or any device plugged to it) is ignored.

```c
bool mb128_init() {
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

## Commands
After **A8** detection sequence, the Memory Base 128 expects to receive either a read or write command described as follows.
| Sequence | Number of bits | Description |
|---:|---:|:---|
| 1 | 1 | request type (**0**: **write**, **1**: **read**) |
| 2 | 10 | address |
| 3 | 3 | bit length (__r__) |
| 4 | 17 | byte length (__N__) |
| 5 | 2 | trailing bits ⚠️ **write command only** |
| 6 | 3 | trailing bits |

Data can now be read or written to the Memory Base 128. First the __N__ bytes are transfered followed by the __r__ remainder bits.
Once the transfer is done, the Memory Base 128 returns to pass-through mode, allowing the joypad states to be read by the console.

Knowing the command format, a single bit read command will be (still in pseudo code):
```c
int mb128_read_bit(uint16_t addr) { 
    if(!mb128_init()) {
        // There is no Memory Base 128.
        return -1;
    }

    mb128_send_bit(1);          // read command

    // address
    for(int i=0; i<10; i++) {
        mb128_send_bit((addr >> i) & 0x01);
    }
    
    // bit size = 1
    mb128_send_bit(1);
    mb128_send_bit(0);
    mb128_send_bit(0);
    
    // 0 bytes
    for(int i=0; i<17; i++) {
        mb128_send_bit(0);
    }
    
    // trailing bits
    mb128_send_bit(0);
    mb128_send_bit(0);
    mb128_send_bit(0);

    // read bit
    return mb128_read_bit();
}    
```

All games studied read or write data by chunks of 512 bytes. We will call it a sector.
Single read sector will be: 
```c
bool mb128_read_sector(uint16_t addr, uint8_t sector[512]) { 
    if(!mb128_init()) {
        // There is no Memory Base 128.
        return -1;
    }

    mb128_send_bit(1);          // read command

    // address
    for(int i=0; i<10; i++) {
        mb128_send_bit((addr >> i) & 0x01);
    }
    
    // bit size = 0
    mb128_send_bit(0);
    mb128_send_bit(0);
    mb128_send_bit(0);
    
    // byte size = 512
    mb128_send_byte(0);
    mb128_send_byte(0x02);
    mb128_send_bit(0)
    
    // trailing bits
    mb128_send_bit(0);
    mb128_send_bit(0);
    mb128_send_bit(0);

    // read bit
    for(int i=0; i<512; i++) {
        sector[i] = mb128_read_bit();
    }
    
    return true;
}    
```

Conversely, writing a sector will be:
```c
bool mb128_write_sector(uint16_t addr, uint8_t sector[512]) { 
    if(!mb128_init()) {
        // There is no Memory Base 128.
        return -1;
    }

    mb128_send_bit(0);          // write command

    // address
    for(int i=0; i<10; i++) {
        mb128_send_bit((addr >> i) & 0x01);
    }
    
    // bit size = 0
    mb128_send_bit(0);
    mb128_send_bit(0);
    mb128_send_bit(0);
    
    // byte size = 512
    mb128_send_byte(0);
    mb128_send_byte(0x02);
    mb128_send_bit(0)

    // trailing bits (write only)
    mb128_send_bit(0);
    mb128_send_bit(0);

    // trailing bits
    mb128_send_bit(0);
    mb128_send_bit(0);
    mb128_send_bit(0);

    // read bit
    for(int i=0; i<512; i++) {
        mb128_send_byte(sector[i]);
    }
    
    return true;
}    
```

## Header format 
The first **2** sectors (**1024** bytes) of the Memory Base 128 holds what can be describe as an entry list. Each entry is **16** bytes long. This means that the those sector can hold **64** entries.
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
 2 | last sector used bytes count (lsb)
 3 | last sector used bytes count (msb)
 4 | CRC (lsb)
 5 | CRC (msb)
 6 | unknown (0x00)
 7 | unknown (0x00)
 8 | entry name
 . |
 f | Last entry name char (0x00)

The first **2** bytes tell where the data is stored (sector number) and how many sectors are used. The meaning of bytes **6** and **7** is unknown. None of the game studied are using them, but they all set those bytes at **0** .

The **CRC** is simply the sum of all stored bytes. This can be translated in the following 
pseudo-C code.
```c
u16 size = (sector_count-1) * 512 + last_sector_used_bytes;
u8  out[ size ]; 
u16 crc = 0;

mb128_read( sector_number, size );

for( i=0; i<size; i++ ) {
    crc += out[ i ];
}
```
The entry name is a **8** bytes string. It is supposed to be unique allowing games to retrieve their data.
Here are some examples :
  * `ﾕｳｼｬM128` for **Tadaima Yusha Boshuuchuu**
  * `MT0     `, `MT1     `, ... for **Shin Megami Tensei**

**Shin Megami Tensei** allows the player to have up to **10** save-states. Where **Tadaima Yusha Boshuuchuu** only allows **1** save-state.

The format of the data stored is not standardized. This means that they are
game dependent. For example, it seems that **Tadaima Yusha Boshuuchuu** is using the Memory Base 128 as an extra **BRAM**. On the other hand, **Shin Megami Tensei** has its own internal format.

## Thanks
  * David Shadoff
  * Elmer

## Contact
mooz at blockos dot org

## License
This document is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0).
[![License: CC BY-NC-SA 4.0](https://licensebuttons.net/l/by-nc-sa/4.0/80x15.png)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

