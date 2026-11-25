# pdcheck.py IMAGE.po - is a ProDOS volume's bookkeeping whole?
#
# Walks every directory from the volume's (block 2) down and claims every
# block each file owns: key, index, master index, data.  Reports a block
# claimed twice (DOUBLE), an entry whose "blocks used" disagrees with what
# it owns (USED MISMATCH), and the bitmap against the claims: blocks the
# bitmap says are in use that nobody owns (lost) and blocks somebody owns
# that the bitmap says are free (the dangerous one).  An independent
# check of what COBOL.OS writes, alongside cp2's own "test".
import sys
d=open(sys.argv[1],'rb').read()
blk=lambda n:d[n*512:(n+1)*512]
own={}
def claim(b,what):
    if b in own: print('DOUBLE',b,own[b],what)
    own[b]=what
for b in (0,1): claim(b,'boot')
vh=blk(2); bm=vh[0x27]|vh[0x28]<<8; tot=vh[0x29]|vh[0x2a]<<8
nbm=(tot+4095)//4096
for i in range(nbm): claim(bm+i,'bitmap')
def entries(key,name):
    b=key
    while b:
        claim(b,'dir '+name)
        B=blk(b)
        for i in range(13):
            e=B[4+39*i:43+39*i]
            if b==key and i==0: continue
            st=e[0]>>4
            if not st: continue
            nm=e[1:1+(e[0]&15)].decode()
            k=e[0x11]|e[0x12]<<8; used=e[0x13]|e[0x14]<<8
            cnt=0
            path=name+'/'+nm
            if st==0xD:
                n0=len(own); entries(k,path)
                nb=0; b2=k
                while b2: nb+=1; b2=blk(b2)[2]|blk(b2)[3]<<8
                if nb!=used: print('USED MISMATCH',path,nb,used)
                continue
            def c(x):
                nonlocal cnt
                if x: claim(x,path); cnt+=1
            if st==1: c(k)
            elif st==2:
                c(k); I=blk(k)
                for j in range(256): c(I[j]|I[256+j]<<8)
            elif st==3:
                c(k); M=blk(k)
                for m in range(128):
                    ix=M[m]|M[256+m]<<8
                    if ix:
                        c(ix); I=blk(ix)
                        for j in range(256): c(I[j]|I[256+j]<<8)
            if cnt!=used: print('USED MISMATCH',path,cnt,used)
        b=B[2]|B[3]<<8
entries(2,'')
free=set()
for b in range(tot):
    byte=blk(bm+b//4096)[(b%4096)//8]
    if byte>>(7-b%8)&1: free.add(b)
used=set(range(tot))-free
print('owned',len(own),'bitmap used',len(used))
print('used not owned',sorted(used-set(own))[:20])
print('owned but free',sorted(set(own)&free)[:20])
