!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2010 EDF S.A., France

!     contact: saturne-support@edf.fr

!     The Code_Saturne Kernel is free software; you can redistribute it
!     and/or modify it under the terms of the GNU General Public License
!     as published by the Free Software Foundation; either version 2 of
!     the License, or (at your option) any later version.

!     The Code_Saturne Kernel is distributed in the hope that it will be
!     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
!     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!     GNU General Public License for more details.

!     You should have received a copy of the GNU General Public License
!     along with the Code_Saturne Kernel; if not, write to the
!     Free Software Foundation, Inc.,
!     51 Franklin St, Fifth Floor,
!     Boston, MA  02110-1301  USA

!-------------------------------------------------------------------------------

subroutine lwcini &
!================

 ( idbia0 , idbra0 ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml , maxelt , lstelt , &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtp    , propce , propfa , propfb , coefa  , coefb  , &
   rdevel , rtuser , ra     )

!===============================================================================
! FONCTION :
! --------

! INITIALISATION DES VARIABLES DE CALCUL
!    POUR LA PHYSIQUE PARTICULIERE : COMBUSTION GAZ MODELE LWC
!    PENDANT DE USINIV.F

! Cette routine est appelee en debut de calcul (suite ou non)
!     avant le debut de la boucle en temps

! Elle permet d'INITIALISER ou de MODIFIER (pour les calculs suite)
!     les variables de calcul,
!     les valeurs du pas de temps


! On dispose ici de ROM et VISCL initialises par RO0 et VISCL0
!     ou relues d'un fichier suite
! On ne dispose des variables VISCLS, CP (quand elles sont
!     definies) que si elles ont pu etre relues dans un fichier
!     suite de calcul

! Les proprietes physiaues sont accessibles dans le tableau
!     PROPCE (prop au centre), PROPFA (aux faces internes),
!     PROPFB (prop aux faces de bord)
!     Ainsi,
!      PROPCE(IEL,IPPROC(IROM  (IPHAS))) designe ROM   (IEL ,IPHAS)
!      PROPCE(IEL,IPPROC(IVISCL(IPHAS))) designe VISCL (IEL ,IPHAS)
!      PROPCE(IEL,IPPROC(ICP   (IPHAS))) designe CP    (IEL ,IPHAS)
!      PROPCE(IEL,IPPROC(IVISLS(ISCAL))) designe VISLS (IEL ,ISCAL)

!      PROPFA(IFAC,IPPROF(IFLUMA(IVAR ))) designe FLUMAS(IFAC,IVAR)

!      PROPFB(IFAC,IPPROB(IROM  (IPHAS))) designe ROMB  (IFAC,IPHAS)
!      PROPFB(IFAC,IPPROB(IFLUMA(IVAR ))) designe FLUMAB(IFAC,IVAR)

! LA MODIFICATION DES PROPRIETES PHYSIQUES (ROM, VISCL, VISCLS, CP)
!     SE FERA EN STANDARD DANS LE SOUS PROGRAMME PPPHYV
!     ET PAS ICI

! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! ndim             ! i  ! <-- ! spatial dimension                              !
! ncelet           ! i  ! <-- ! number of extended (real + ghost) cells        !
! ncel             ! i  ! <-- ! number of cells                                !
! nfac             ! i  ! <-- ! number of interior faces                       !
! nfabor           ! i  ! <-- ! number of boundary faces                       !
! nfml             ! i  ! <-- ! number of families (group classes)             !
! nprfml           ! i  ! <-- ! number of properties per family (group class)  !
! nnod             ! i  ! <-- ! number of vertices                             !
! lndfac           ! i  ! <-- ! size of nodfac indexed array                   !
! lndfbr           ! i  ! <-- ! size of nodfbr indexed array                   !
! ncelbr           ! i  ! <-- ! number of cells with faces on boundary         !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! nphas            ! i  ! <-- ! number of phases                               !
! nideve, nrdeve   ! i  ! <-- ! sizes of idevel and rdevel arrays              !
! nituse, nrtuse   ! i  ! <-- ! sizes of ituser and rtuser arrays              !
! ifacel(2, nfac)  ! ia ! <-- ! interior faces -> cells connectivity           !
! ifabor(nfabor)   ! ia ! <-- ! boundary faces -> cells connectivity           !
! ifmfbr(nfabor)   ! ia ! <-- ! boundary face family numbers                   !
! ifmcel(ncelet)   ! ia ! <-- ! cell family numbers                            !
! iprfml           ! ia ! <-- ! property numbers per family                    !
!  (nfml, nprfml)  !    !     !                                                !
! maxelt           ! i  ! <-- ! max number of cells and faces (int/boundary)   !
! lstelt(maxelt)   ! ia ! --- ! work array                                     !
! ipnfac(nfac+1)   ! ia ! <-- ! interior faces -> vertices index (optional)    !
! nodfac(lndfac)   ! ia ! <-- ! interior faces -> vertices list (optional)     !
! ipnfbr(nfabor+1) ! ia ! <-- ! boundary faces -> vertices index (optional)    !
! nodfbr(lndfbr)   ! ia ! <-- ! boundary faces -> vertices list (optional)     !
! idevel(nideve)   ! ia ! <-> ! integer work array for temporary development   !
! ituser(nituse)   ! ia ! <-> ! user-reserved integer work array               !
! ia(*)            ! ia ! --- ! main integer work array                        !
! xyzcen           ! ra ! <-- ! cell centers                                   !
!  (ndim, ncelet)  !    !     !                                                !
! surfac           ! ra ! <-- ! interior faces surface vectors                 !
!  (ndim, nfac)    !    !     !                                                !
! surfbo           ! ra ! <-- ! boundary faces surface vectors                 !
!  (ndim, nfabor)  !    !     !                                                !
! cdgfac           ! ra ! <-- ! interior faces centers of gravity              !
!  (ndim, nfac)    !    !     !                                                !
! cdgfbo           ! ra ! <-- ! boundary faces centers of gravity              !
!  (ndim, nfabor)  !    !     !                                                !
! xyznod           ! ra ! <-- ! vertex coordinates (optional)                  !
!  (ndim, nnod)    !    !     !                                                !
! volume(ncelet)   ! ra ! <-- ! cell volumes                                   !
! dt(ncelet)       ! tr ! <-- ! valeur du pas de temps                         !
! rtp              ! tr ! <-- ! variables de calcul au centre des              !
! (ncelet,*)       !    !     !    cellules                                    !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa coefb      ! tr ! <-- ! conditions aux limites aux                     !
!  (nfabor,*)      !    !     !    faces de bord                               !
! rdevel(nrdeve)   ! ra ! <-> ! real work array for temporary development      !
! rtuser(nrtuse)   ! ra ! <-> ! user-reserved real work array                  !
! ra(*)            ! ra ! --- ! main real work array                           !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use coincl
use cpincl
use ppincl

!===============================================================================

implicit none

integer          idbia0 , idbra0
integer          ndim   , ncelet , ncel   , nfac   , nfabor
integer          nfml   , nprfml
integer          nnod   , lndfac , lndfbr , ncelbr
integer          nvar   , nscal  , nphas
integer          nideve , nrdeve , nituse , nrtuse

integer          ifacel(2,nfac) , ifabor(nfabor)
integer          ifmfbr(nfabor) , ifmcel(ncelet)
integer          iprfml(nfml,nprfml), maxelt, lstelt(maxelt)
integer          ipnfac(nfac+1), nodfac(lndfac)
integer          ipnfbr(nfabor+1), nodfbr(lndfbr)
integer          idevel(nideve), ituser(nituse), ia(*)

double precision xyzcen(ndim,ncelet)
double precision surfac(ndim,nfac), surfbo(ndim,nfabor)
double precision cdgfac(ndim,nfac), cdgfbo(ndim,nfabor)
double precision xyznod(ndim,nnod), volume(ncelet)
double precision dt(ncelet), rtp(ncelet,*), propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision rdevel(nrdeve), rtuser(nrtuse), ra(*)

! Local variables

character*80     chaine
integer          idebia, idebra
integer          iel, mode, igg, iphas, izone
integer          iscal, ivar, ii
double precision hinit, coefg(ngazgm), hair, tinitk
double precision sommqf, sommqt, sommq, tentm, fmelm
double precision valmax, valmin, xkent, xeent, d2s3

! NOMBRE DE PASSAGES DANS LA ROUTINE

integer          ipass
data             ipass /0/
save             ipass

!===============================================================================

!===============================================================================
! 1.  INITIALISATION VARIABLES LOCALES
!===============================================================================

ipass = ipass + 1

idebia = idbia0
idebra = idbra0

do igg = 1, ngazgm
  coefg(igg) = zero
enddo

iphas  = 1

d2s3 = 2.d0/3.d0

!===============================================================================
! 2. INITIALISATION DES INCONNUES :
!      UNIQUEMENT SI ON NE FAIT PAS UNE SUITE
!===============================================================================

if ( isuite.eq.0 ) then

! ---> Initialisation au 1er passage avec de l'air a TINITK
!                                    ======================

  if ( ipass.eq.1 ) then

! ----- Temperature du melange : air a TINITK
    tinitk = t0(iphas)

! ----- Enthalpie de l'air a TINITK
    if ( ippmod(icolwc).eq.1 .or. ippmod(icolwc).eq.3 .or.        &
         ippmod(icolwc).eq.5  ) then
      coefg(1) = zero
      coefg(2) = 1.d0
      coefg(3) = zero
      mode     = -1
      call cothht                                                 &
      !==========
        ( mode   , ngazg , ngazgm  , coefg  ,                     &
          npo    , npot   , th     , ehgazg ,                     &
          hair   , tinitk )
    endif

! ----- On en profite pour initialiser FRMEL et TGF
!       CAR on n'a pas encore vu usebuc.F

    frmel = zero
    tgf   = 300.d0

! ---- Initialisation de k et epsilon

    xkent = 1.d-10
    xeent = 1.d-10

    do iel = 1, ncel

! ---- TURBULENCE

      if (itytur(iphas).eq.2) then

        rtp(iel,ik(iphas))  = xkent
        rtp(iel,iep(iphas)) = xeent

      elseif (itytur(iphas).eq.3) then

        rtp(iel,ir11(iphas)) = d2s3*xkent
        rtp(iel,ir22(iphas)) = d2s3*xkent
        rtp(iel,ir33(iphas)) = d2s3*xkent
        rtp(iel,ir12(iphas)) = 0.d0
        rtp(iel,ir13(iphas)) = 0.d0
        rtp(iel,ir23(iphas)) = 0.d0
        rtp(iel,iep(iphas))  = xeent

      elseif (iturb(iphas).eq.50) then

        rtp(iel,ik(iphas))   = xkent
        rtp(iel,iep(iphas))  = xeent
        rtp(iel,iphi(iphas)) = d2s3
        rtp(iel,ifb(iphas))  = 0.d0

      elseif (iturb(iphas).eq.60) then

        rtp(iel,ik(iphas))   = xkent
        rtp(iel,iomg(iphas)) = xeent/cmu/xkent

      endif

! ----- Fraction massique de fuel et sa variance

      rtp(iel,isca(iyfm)) = fmax
      rtp(iel,isca(iyfp2m)) = zero

! ----- Fraction de melange et sa variance

      rtp(iel,isca(ifm))   = fmax
      rtp(iel,isca(ifp2m)) = zero

      if ( ippmod(icolwc).ge. 2) then
        rtp(iel,isca(icoyfp))   = zero
      endif

! ----- Enthalpie du melange

      if ( ippmod(icolwc).eq.1 .or. ippmod(icolwc).eq.3 .or.      &
          ippmod(icolwc).eq.5) then
        rtp(iel,isca(ihm)) = hair
      endif

    enddo

! ---> Initialisation au 2eme passage

  else if ( ipass.eq.2 ) then

! ----- Calculs preliminaires : Fraction de melange, T, H
!     (la valeur NOZAPM est utilisee pour inclure les aspects parall)
    sommqf = zero
    sommq  = zero
    sommqt = zero
    do izone = 1, nozapm
      sommqf = sommqf + qimp(izone)*fment(izone)
      sommqt = sommqt + qimp(izone)*tkent(izone)
      sommq  = sommq  + qimp(izone)
    enddo

    if(abs(sommq).gt.epzero) then
      fmelm = sommqf / sommq
      tentm = sommqt / sommq
    else
      fmelm = zero
      tentm = t0(iphas)
    endif

! ----- Enthalpie du melange HINIT
    if ( ippmod(icolwc).eq.1 .or. ippmod(icolwc).eq.3 .or.        &
        ippmod(icolwc).eq.5  ) then
      coefg(1) = fmelm
      coefg(2) = (1.d0-fmelm)
      coefg(3) = zero
      mode     = -1
      call cothht                                                 &
      !==========
        ( mode   , ngazg , ngazgm  , coefg  ,                     &
          npo    , npot   , th     , ehgazg ,                     &
          hinit  , tentm )
    endif


! ----- On donne la main a l'utilisateur

    call uslwci                                                   &
    !==========
 ( idebia , idebra ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml , maxelt , lstelt , &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtp    , propce , propfa , propfb , coefa  , coefb  , &
   rdevel , rtuser , ra     )

! ----- En periodique et en parallele,
!       il faut echanger ces initialisations (qui sont en fait dans RTPA)

    if (irangp.ge.0.or.iperio.eq.1) then
      call synsca(rtp(1,isca(iyfm)))
      !==========
      call synsca(rtp(1,isca(iyfp2m)))
        !==========
      call synsca(rtp(1,isca(ifm)))
      !==========
      call synsca(rtp(1,isca(ifp2m)))
      !==========

      if ( ippmod(icolwc).ge.2) then
        call synsca(rtp(1,isca(icoyfp)))
        !==========
      endif

      if (ippmod(icolwc).eq.1 .or. ippmod(icolwc).eq.3 .or.       &
          ippmod(icolwc).eq.5 ) then
        call synsca(rtp(1,isca(ihm)))
        !==========
      endif

    endif


!      Impressions de controle

    write(nfecra,2000)

    do ii  = 1, nscapp
      iscal = iscapp(ii)
      ivar  = isca(iscal)
      valmax = -grand
      valmin =  grand
      do iel = 1, ncel
        valmax = max(valmax,rtp(iel,ivar))
        valmin = min(valmin,rtp(iel,ivar))
      enddo
      chaine = nomvar(ipprtp(ivar))
      if (irangp.ge.0) then
        call parmin(valmin)
        !==========
        call parmax(valmax)
        !==========
      endif
      write(nfecra,2010)chaine(1:8),valmin,valmax
    enddo

    write(nfecra,2020)

  endif

endif

!----
! FORMATS
!----


 2000 format(                                                           &
'                                                             ',/,&
' ----------------------------------------------------------- ',/,&
'                                                             ',/,&
'                                                             ',/,&
' ** INITIALISATION DES VARIABLES PROPRES AU GAZ (FL PRE LWC) ',/,&
'    -------------------------------------------------------- ',/,&
'           2eme PASSAGE                                      ',/,&
' ---------------------------------                           ',/,&
'  Variable  Valeur min  Valeur max                           ',/,&
' ---------------------------------                           '  )

 2010 format(                                                           &
 2x,     a8,      e12.4,      e12.4                              )

 2020 format(                                                           &
' ---------------------------------                           ',/)

!----
! FIN
!----

return
end subroutine
