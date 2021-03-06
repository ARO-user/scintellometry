integer, parameter :: nhead=0*32*1024*1024,nblock=512/1, nt=26200,&
ntint=1024*32*1024/(nblock*2)/4,ngate=32*4,ntbin=16*2,ntw=128*2*100
!nt=45 for 1508, 180 for 0809 and 156 for 0531
integer, parameter :: npulsar=4
integer*1, dimension(nhead) :: raw1
integer*1, dimension(2,nblock) :: raw4
complex, dimension(nblock) :: cbufx,cbufy,cbufold
real, dimension(nblock,ngate) :: foldspec
real, dimension(nblock,ngate) :: foldspec1
real, dimension(nblock,ngate,ntbin) :: foldspec2
real, dimension(ngate,ntbin) :: foldspec3
integer,dimension(nblock,ngate)::icount
real, dimension(nblock,nt*ntint/ntw) :: waterfall
real, dimension(nblock,ntbin) :: dynspect,dynspect2,dall
real*8 t0,t,dt,samplerate,t1,ft0,p0
character*7 psrname(npulsar)
real*8 p00(npulsar),dm0(npulsar)
integer igate(4,npulsar)
character*255 fndir1,fndir2

fndir1='/mnt/scratch-3week/pen/Pulsar/'
fndir2=fndir1
!fndir1='/mnt/data1/haoran/sept10_pulsarvlbi_gmrt/R1/'
!fndir2='/mnt/data1/haoran/sept10_pulsarvlbi_gmrt/R2/'

ipsr=3
igate=1
!igate(:,2)=(/59,60,61,62/)
!igate(:,4)=(/224,226,227,231/)
psrname=(/'1937+21','1929+10','1957+20','1919+21'/)
! for may 17, 4AM
p00=(/1.55788743954070/1000,226.53301064496944/1000,1.60731438719155/1000*(1-4*3.252e-07),1337.21932367595014/1000 /)
dm0=(/5.75130,19.5990,29.11680,12.4309/)
dm0=(/5.75130,19.5990,29.1168*1.001,12.4309/)
dm0=(/5.75130,19.5990,29.121390086960949536-29.1168*1.001,12.4309*0/)
dm0=(/0*5.75130,0*3.17600,0.,12.4309*0/)
open(10,file=trim(fndir1)//psrname(ipsr)//'L.float',status='old',access='stream')

p0=p00(ipsr)
dm=dm0(ipsr)

foldspec=0
icount=0
samplerate=33333333*2 !MSPS
waterfall=0
cbufold=0
do j=1,nt
   t1=(j-1)*2*nblock*(ntint/samplerate)
   if (mod(j,10) .eq.0) write(*,*) t1
   t0=t1
   ibin=(j-1)*ntbin/nt+1
   iresid=mod(j,nt/ntbin)
   do i=1,ntint
      raw4=0
      if (mod(j,16)<8) then
   !      if (i .le. ntint/2) then
   !         read(10,end=100) raw4
   !      else
   !         read(11,end=100) raw4
   !      endif
	read(10,end=100) cbufx
      else
         cycle
      end if
      iw=(j-1)*(ntint)+i-1
      iw0=iw/ntw+1
!      cbufx=cmplx(raw4(1,:)*1.,raw4(2,:)*1.)
!      if (mod(i,2) .eq. 0) cbufx=cbufx-cbufold
!      if (mod(i,2) .eq. 0 .and. mod(j,16) .eq. 1 .and. i .eq. 2) write(*,*)sum(cbufx*conjg(cbufold))/sqrt(sum(abs(cbufx)**2)*sum(abs(cbufold)**2))
      cbufold=cbufx
!      write(*,*) iw0,nt*ntint/ntw
      if( iw0>nt*ntint/ntw) cycle
      waterfall(:,iw0)=waterfall(:,iw0)+abs(cbufx)**2
!$omp parallel do default(none) private(freq,dt,t,iphase) shared(t0,p0,dm,foldspec,cbufx,icount,ibin,i,samplerate)
      do if=1,nblock
!         freq=156.-16.6666666*if/nblock
         freq=306.+2*16.6666666*if/nblock
         dt=4149*dm/freq**2-4149*dm/306**2
         t=t0+i*(2*nblock)/samplerate-dt+p0/3
         iphase=ngate*t/p0
         iphase=mod(iphase+4000000*ngate,ngate)+1
         foldspec(if,iphase)=foldspec(if,iphase)+abs(cbufx(if))**2
         if (cbufx(if)**2 .ne. 0)icount(if,iphase)=icount(if,iphase)+1
      end do      
   end do
if (iresid .eq. 0) then
where(icount>0) 
foldspec=foldspec/icount
elsewhere
foldspec=0
endwhere
where(foldspec .ne. 0) foldspec=foldspec-spread(sum(foldspec,2)/count(foldspec .ne. 0,2),2,ngate)
foldspec1=foldspec1+foldspec
foldspec2(:,:,ibin)=foldspec
dynspect(:,ibin)=sum(foldspec(:,igate(1,ipsr):igate(2,ipsr)),2)
dynspect2(:,ibin)=sum(foldspec(:,igate(3,ipsr):igate(4,ipsr)),2)
foldspec=0
icount=0
endif
end do
100 continue
nt1=j-1
write(*,*) 'read',nt1,'out of ',nt
where (waterfall .ne. 0) waterfall=waterfall-spread(sum(waterfall,2)/count(waterfall .ne. 0,2),2,nt*ntint/ntw)
call pmap('waterfall.pgm',waterfall,nblock,nt*ntint/ntw,2)
open(10,file='flux.dat')
do i=1,ngate
write(10,*) i,sum(foldspec1(:,i),1)
enddo
call pmap('folded'//psrname(ipsr)//'.pgm',foldspec1,nblock,ngate,1)
foldspec3=sum(foldspec2,1)
open(10,file='folded'//psrname(ipsr)//'.bin',access='stream')
write(10) foldspec2
call pmap('foldedbin'//psrname(ipsr)//'.pgm',foldspec2,nblock,ngate*ntbin,1)
open(10,file='folded1'//psrname(ipsr)//'.bin',access='stream')
write(10) foldspec3
call pmap('folded3'//psrname(ipsr)//'.pgm',foldspec3,ngate,ntbin,1)
open(10,file='dynspect'//psrname(ipsr)//'.bin',access='stream')
write(10) dynspect
write(10) dynspect2
dall=dynspect+dynspect2
dall=dall/spread(sum(dall,1)/nblock,1,nblock)
dynspect=dynspect/spread(sum(dynspect,1)/nblock,1,nblock)
dynspect2=dynspect2/spread(sum(dynspect2,1)/nblock,1,nblock)
dall(1,:)=0
call pmap('dynspect'//psrname(ipsr)//'.pgm',dall,nblock,ntbin,1)
dynspect=dynspect-dynspect2
dynspect(1,:)=0
call pmap('dynspectdiff'//psrname(ipsr)//'.pgm',dynspect,nblock,ntbin,1)
 
contains
  subroutine pmap(fn,rmap1,nx,ny,iscale)
  real rmap(nx,ny),rmap1(nx,ny)
  integer*2, dimension(nx,ny) :: imap
  integer*1, dimension(nx,ny) :: imap1
  character(len=*):: fn
  integer npix,mypos

  npix=min(ny/2-1,nx/2-1,300)
  
  
  rmap=rmap1
!  write(*,*) 'rms=',sqrt(sum(rmap(nx/2-npix:nx/2+npix,ny/2-npix:ny/2+npix)**2)/npix**2/4)
  iscale1=iscale
  do while (iscale1 > 1)      
     rmap=sign((sqrt(abs(rmap))),rmap)
     iscale1=iscale1-1
  end do
  rmax=maxval(rmap)
  rmin=minval(rmap)
  write(*,*) trim(fn),rmax,rmin
  imap=255*(rmap-rmin)/(rmax-rmin)
  imap1=127*(rmap-rmin)/(rmax-rmin)
  open(10,file=fn)
  write(10,'(2hP5)')
  write(10,*)nx,ny
  write(10,*) 255
!  write(10,*) 127
!  INQUIRE(UNIT=10, POS=mypos)
  close(10)
  open(10,file=fn, access='stream',position='append')
!  write(10,pos=mypos) int(imap,1)
  write(10) int(imap,1)
  close(10)
end subroutine pmap

end
