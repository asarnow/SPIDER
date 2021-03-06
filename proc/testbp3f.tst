; SOURCE:   testbp3f.tst
; PURPOSE:  Test 'BP 3F'  & 'BP 32F'

MD 
SET MP
0

MO            ; Create test image for projection
jnk001        ; Output file
75 75         ; Size
T             ; Sine wave

DO [inum]=2,12
   CP
   jnk001
   jnk{***[inum]}
ENDDO

VM
echo ' Testing BP 3F with 12 images -----'

BP 3F         ; Run  backprojection
jnk***        ; Template for 2-d input images 
1-12          ; File numbers
savangbprp    ; Angles doc file
*             ; No symmmetries
jnkbp3f_out   ; Output volume

FS x12,x11    ; Get volume statistics
jnkbp3f_out   ; Input file

VM            : Echo volume statistics
echo ' BP 3F     Range: {%g13.5%x11}...{%g13.5%x12}'
VM
echo ' Correct   Range:  -0.12581E-01...  0.13152E-01'
VM            
echo '  '

VM
echo ' Testing BP 32F with 12 images ----'

BP 32F          ; Run  backprojection now
jnk***          ; Template for 2-d input images 
1-12            ; File numbers
savangbprp      ; Angles doc file
*               ; No symmmetries
jnkbp32fb_out   ; Input file
jnkbp32f1_out   ; Input file
jnkbp32f2_out   ; Input file

FS x12,x11    ; Get volume statistics
jnkbp32fb_out   ; Input file

VM            : Echo volume statistics
echo ' BP 32F    Range: {%g13.5%x11}...{%g13.5%x12}'
VM
echo ' Correct   Range:  -0.12581E-01...  0.13152E-01'
VM            
echo '  '


RE


