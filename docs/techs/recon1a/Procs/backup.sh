ln -s $BACKUP Bak

date
echo "Copying batch files"
cp -a *.tar* Bak/
tar cf Bak/allbatch.tar */*spi Refinement/*pam

echo "Copying top-level parameters"
cp -a *.dat Bak/

echo "Copying micrographs (slow)"
mkdir Bak/Micrographs
cp -av Micrographs/mic* Bak/Micrographs/

echo "Copying defocus parameters"
tar cf  Bak/powerspectra.tar Power_Spectra/*.dat

echo "Copying particle coordinates"
tar cf Bak/coords.tar Particles/coords/sndc*

echo "Copying particles-per-micrograph"
tar cf  Bak/orderpicked.tar Particles/*.dat

echo "Copying selected particles"
tar cf  Bak/partselect.tar Particles/good/*

echo "Copying alignment files"
mkdir Bak/Alignment
cp -a Alignment/*.dat Bak/Alignment

echo "Copying initial-reconstruction data"
mkdir Bak/Reconstruction
cp -a Reconstruction/*.dat Bak/Reconstruction/

echo "Copying refinement data"
mkdir Bak/Refinement
cp -ra Refinement/input Bak/Refinement/
cp -ra Refinement/final Bak/Refinement/



echo; echo "Done"; date
