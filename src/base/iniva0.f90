!-------------------------------------------------------------------------------

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2013 EDF S.A.
!
! This program is free software; you can redistribute it and/or modify it under
! the terms of the GNU General Public License as published by the Free Software
! Foundation; either version 2 of the License, or (at your option) any later
! version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
! FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
! details.
!
! You should have received a copy of the GNU General Public License along with
! this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
! Street, Fifth Floor, Boston, MA 02110-1301, USA.

!-------------------------------------------------------------------------------

subroutine iniva0 &
!================

 ( nvar   , nscal  , ncofab ,                                     &
   dt     , tpucou , rtp    , propce , propfb ,                   &
   coefa  , coefb  , frcxt  , prhyd)

!===============================================================================
! FONCTION :
! --------

! INITIALISATION DES VARIABLES DE CALCUL, DU PAS DE TEMPS
!  ET DU TABLEAU INDICATEUR DU CALCUL DE LA DISTANCE A LA PAROI
!  AUX VALEURS PAR DEFAUT
!                AVANT LECTURE EVENTUELLE DU FICHIER SUITE ET
!                AVANT DE PASSER LA MAIN A L'UTILISATEUR
!-------------------------------------------------------------------------------
!ARGU                             ARGUMENTS
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ncofab           ! e  ! <-- ! nombre de couples coefa/b pour les cl          !
! dt(ncelet)       ! tr ! <-- ! valeur du pas de temps                         !
! rtp              ! tr ! <-- ! variables de calcul au centre des              !
! (ncelet,*)       !    !     !    cellules                                    !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa coefb      ! tr ! <-- ! conditions aux limites aux                     !
!  (nfabor,*)      !    !     !    faces de bord                               !
! frcxt(3,ncelet)  ! tr ! <-- ! force exterieure generant la pression          !
!                  !    !     !  hydrostatique                                 !
! prhyd(ncelet)    ! ra ! <-- ! hydrostatic pressure predicted                 !
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
use pointe
use entsor
use albase
use parall
use period
use ppppar
use ppthch
use ppincl
use cplsat
use field
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal  , ncofab

double precision dt(ncelet), tpucou(ncelet,3), rtp(ncelet,*), propce(ncelet,*)
double precision propfb(nfabor,*)
double precision coefa(nfabor,ncofab), coefb(nfabor,ncofab)
double precision frcxt(3,ncelet), prhyd(ncelet)

! Local variables

integer          iis   , ivar  , iscal , imom
integer          iel   , ifac  , isou  , jsou
integer          iclip , ii    , jj    , idim
integer          iirom , iiromb, iiroma
integer          iivisl, iivist, iivisa, iivism
integer          iicp  , iicpa
integer          iiviss, iiptot
integer          iptsna, iptsta, iptsca
integer          nn
integer          iflid, nfld, ifmaip, bfmaip, iflmas, iflmab

double precision xxk, xcmu, trii

double precision rvoid(1)

!===============================================================================

!===============================================================================
! 1.  INITIALISATION
!===============================================================================

! Initialize variables to avoid compiler warnings

jj = 0

! Memoire


! En compressible, ISYMPA initialise (= 1) car utile dans le calcul
!     du pas de temps variable avant passage dans les C.L.

if ( ippmod(icompf).ge.0 ) then
  do ifac = 1, nfabor
    isympa(ifac) = 1
  enddo
endif

!===============================================================================
! 2. PAS DE TEMPS
!===============================================================================

! dt might be used on the halo cells during the ALE initialization
! otherwise dt is synchronized in the pressure correction step.
do iel = 1, ncelet
  dt (iel) = dtref
enddo

!===============================================================================
! 3.  INITIALISATION DES PROPRIETES PHYSIQUES
!===============================================================================

!     Masse volumique
iirom  = ipproc(irom  )
iiromb = ipprob(irom  )

!     Masse volumique aux cellules (et au pdt precedent si ordre2 ou icalhy)
do iel = 1, ncel
  propce(iel,iirom)  = ro0
enddo
if (iroext.gt.0.or.icalhy.eq.1.or.idilat.gt.1) then
  iiroma = ipproc(iroma )
  do iel = 1, ncel
    propce(iel,iiroma) = propce(iel,iirom)
  enddo
endif
!     Masse volumique aux faces de bord (et au pdt precedent si ordre2)
do ifac = 1, nfabor
  propfb(ifac,iiromb) = ro0
enddo
if(iroext.gt.0) then
  iiroma = ipprob(iroma )
  do ifac = 1, nfabor
    propfb(ifac,iiroma) = propfb(ifac,iiromb)
  enddo
endif

!     Viscosite moleculaire
iivisl = ipproc(iviscl)
iivist = ipproc(ivisct)

!     Viscosite moleculaire aux cellules (et au pdt precedent si ordre2)
do iel = 1, ncel
  propce(iel,iivisl) = viscl0
enddo
if(iviext.gt.0) then
  iivisa = ipproc(ivisla)
  do iel = 1, ncel
    propce(iel,iivisa) = propce(iel,iivisl)
  enddo
endif
!     Viscosite turbulente aux cellules (et au pdt precedent si ordre2)
do iel = 1, ncel
  propce(iel,iivist) = 0.d0
enddo
if(iviext.gt.0) then
  iivisa = ipproc(ivista)
  do iel = 1, ncel
    propce(iel,iivisa) = propce(iel,iivist)
  enddo
endif

!     Chaleur massique aux cellules (et au pdt precedent si ordre2)
if(icp.gt.0) then
  iicp = ipproc(icp)
  do iel = 1, ncel
    propce(iel,iicp) = cp0
  enddo
  if(icpext.gt.0) then
    iicpa  = ipproc(icpa)
    do iel = 1, ncel
      propce(iel,iicpa ) = propce(iel,iicp)
    enddo
  endif
endif

! La pression totale sera initialisee a P0 + rho.g.r dans INIVAR
!  si l'utilisateur n'a pas fait d'initialisation personnelle
! Non valable en compressible
if (ippmod(icompf).lt.0) then
  iiptot = ipproc(iprtot)
  do iel = 1, ncel
    propce(iel,iiptot) = - rinfin
  enddo
endif

! Diffusivite des scalaires
do iscal = 1, nscal
  if (ivisls(iscal).gt.0) then
    iiviss = ipproc(ivisls(iscal))
    ! Diffusivite aux cellules (et au pdt precedent si ordre2)
    do iel = 1, ncel
      propce(iel,iiviss) = visls0(iscal)
    enddo
    if (ivsext(iscal).gt.0) then
      iivisa = ipproc(ivissa(iscal))
      do iel = 1, ncel
        propce(iel,iivisa) = propce(iel,iiviss)
      enddo
    endif
  endif

  if (iscal.eq.iscalt.and.iturt(iscal).gt.0.and.irovar.eq.1) then
    do iel = 1, ncelet
      propce(iel,ipproc(ibeta)) = 0.d0
    enddo
  endif
enddo

! Initialisation of source terms for weakly compressible algorithm
if (idilat.eq.4) then
  do iel = 1, ncel
    propce(iel,ipproc(iustdy(itsrho))) = 0.d0
  enddo
  do iscal = 1, nscal
    do iel = 1, ncel
      propce(iel,ipproc(iustdy(iscal))) = 0.d0
    enddo
  enddo
endif


!     Viscosite de maillage en ALE
if (iale.eq.1) then
  nn = 1
  if (iortvm.eq.1) nn = 3
  do ii = 1, nn
    iivism = ipproc(ivisma(ii))
    do iel = 1, ncel
      propce(iel,iivism) = 1.d0
    enddo
  enddo
endif

!===============================================================================
! 4. INITIALISATION STANDARD DES VARIABLES DE CALCUL
!     On complete ensuite pour les variables turbulentes et les scalaires
!===============================================================================

!     Toutes les variables a 0
do ivar = 1, nvar
  do iel = 1, ncel
    rtp(iel,ivar) = 0.d0
  enddo
enddo

!     On met la pression P* a PRED0
do iel = 1, ncel
  rtp(iel,ipr) = pred0
enddo

!     Couplage U-P
if(ipucou.eq.1) then
  do iel = 1, ncel
    tpucou(iel,1) = 0.d0
    tpucou(iel,2) = 0.d0
    tpucou(iel,3) = 0.d0
  enddo
endif

!===============================================================================
! 5. INITIALISATION DE K, RIJ ET EPS
!===============================================================================

!  Si UREF n'a pas ete donnee par l'utilisateur ou a ete mal initialisee
!    (valeur negative), on met les valeurs de k, Rij, eps et omega a
!    -10*GRAND. On testera ensuite si l'utilisateur les a modifiees dans
!    usiniv ou en lisant un fichier suite.

if(itytur.eq.2 .or. itytur.eq.5) then

  xcmu = cmu
  if (iturb.eq.50) xcmu = cv2fmu
  if (iturb.eq.51) xcmu = cpalmu

  if (uref.ge.0.d0) then
    do iel = 1, ncel
      rtp(iel,ik) = 1.5d0*(0.02d0*uref)**2
      rtp(iel,iep) = rtp(iel,ik)**1.5d0*xcmu/almax
    enddo

    iclip = 1
    call clipke(ncelet , ncel   , nvar    ,     &
         iclip  , iwarni(ik),                   &
         propce , rtp    )

  else
    do iel = 1, ncel
      rtp(iel,ik) = -grand
      rtp(iel,iep) = -grand
    enddo
  endif

  if (iturb.eq.50) then
    do iel = 1, ncel
      rtp(iel,iphi) = 2.d0/3.d0
      rtp(iel,ifb) = 0.d0
    enddo
  endif
  if (iturb.eq.51) then
    do iel = 1, ncel
      rtp(iel,iphi) = 2.d0/3.d0
      rtp(iel,ial) = 1.d0
    enddo
  endif

elseif(itytur.eq.3) then

  if (uref.ge.0.d0) then

    trii   = (0.02d0*uref)**2

    do iel = 1, ncel
      rtp(iel,ir11) = trii
      rtp(iel,ir22) = trii
      rtp(iel,ir33) = trii
      rtp(iel,ir12) = 0.d0
      rtp(iel,ir13) = 0.d0
      rtp(iel,ir23) = 0.d0
      xxk = 0.5d0*(rtp(iel,ir11)+                             &
           rtp(iel,ir22)+rtp(iel,ir33))
      rtp(iel,iep) = xxk**1.5d0*cmu/almax
    enddo
    iclip = 1
    call clprij(ncelet , ncel   , nvar    ,     &
         iclip  ,                               &
         propce , rtp    , rtp    )

  else

    do iel = 1, ncel
      rtp(iel,ir11) = -grand
      rtp(iel,ir22) = -grand
      rtp(iel,ir33) = -grand
      rtp(iel,ir12) = -grand
      rtp(iel,ir13) = -grand
      rtp(iel,ir23) = -grand
      rtp(iel,iep)  = -grand
    enddo

    if(iturb.eq.32)then
      do iel = 1, ncel
        rtp(iel,ial) = 1.d0
      enddo
    endif

 endif

elseif(iturb.eq.60) then

  if (uref.ge.0.d0) then

    do iel = 1, ncel
      rtp(iel,ik ) = 1.5d0*(0.02d0*uref)**2
      !     on utilise la formule classique eps=k**1.5/Cmu/ALMAX et omega=eps/Cmu/k
      rtp(iel,iomg) = rtp(iel,ik)**0.5d0/almax
    enddo
    !     pas la peine de clipper, les valeurs sont forcement positives

  else

    do iel = 1, ncel
      rtp(iel,ik ) = -grand
      rtp(iel,iomg) = -grand
    enddo

  endif

elseif(iturb.eq.70) then

  if (uref.ge.0.d0) then

    do iel = 1, ncel
      rtp(iel,inusa ) = sqrt(1.5d0)*(0.02d0*uref)*almax
      !     on utilise la formule classique eps=k**1.5/Cmu/ALMAX
      !     et nusa=Cmu*k**2/eps
    enddo
    !     pas la peine de clipper, les valeurs sont forcement positives

  else

    do iel = 1, ncel
      rtp(iel,inusa ) = -grand
    enddo

  endif

endif

!===============================================================================
! 6.  CLIPPING DES GRANDEURS SCALAIRES (SF K-EPS VOIR CI DESSUS)
!===============================================================================

if (nscal.gt.0) then

!    Clipping des scalaires non variance
  do iis = 1, nscal
    if(iscavr(iis).eq.0) then
      iscal = iis
      call clpsca(ncelet, ncel, iscal, rvoid, rtp)
      !==========
    endif
  enddo

!     Clipping des variances qui sont clippees sans recours au scalaire
!        associe
  do iis = 1, nscal
    if(iscavr(iis).ne.0.and.iclvfl(iis).ne.1) then
      iscal = iis
      call clpsca(ncelet, ncel, iscal, rvoid, rtp)
      !==========
    endif
  enddo

!     Clipping des variances qui sont clippees avec recours au scalaire
!        associe s'il est connu
  do iis = 1, nscal
    if (iscavr(iis).le.nscal.and.iscavr(iis).ge.1.and.iclvfl(iis).eq.1) then
      iscal = iis
      call clpsca(ncelet, ncel, iscal, rtp(1,isca(iscavr(iis))), rtp)
      !==========
    endif
  enddo

endif

!===============================================================================
! 7.  INITIALISATION DE CONDITIONS AUX LIMITES ET FLUX DE MASSE
!      NOTER QUE LES CONDITIONS AUX LIMITES PEUVENT ETRE UTILISEES DANS
!      PHYVAR, PRECLI
!===============================================================================

! Conditions aux limites
do ii = 1, ncofab
  do ifac = 1, nfabor
    coefa(ifac,ii) = 0.d0
    coefb(ifac,ii) = 1.d0
  enddo
enddo

do ifac = 1, nfabor
  coefb(ifac,iclrtp(iu,icoefc)) = 0.d0
  coefb(ifac,iclrtp(iv,icoefc)) = 0.d0
  coefb(ifac,iclrtp(iw,icoefc)) = 0.d0
  coefb(ifac,iclrtp(isca(ienerg),icoefc)) = 0.d0
enddo

! Boundary conditions for the velocity if coupling of the components
if (ivelco.eq.1) then
  do ifac = 1, nfabor
    do isou = 1, 3
      coefau(isou,ifac) = 0.d0
      cofafu(isou,ifac) = 0.d0
      do jsou = 1, 3
        if (jsou.eq.isou) then
          coefbu(isou,jsou,ifac) = 1.d0
          cofbfu(isou,jsou,ifac) = 0.d0
        else
          coefbu(isou,jsou,ifac) = 0.d0
          cofbfu(isou,jsou,ifac) = 0.d0
        endif
      enddo
    enddo
  enddo
endif



do ifac = 1, nfabor
  itypfb(ifac) = 0
  itrifb(ifac) = 0
enddo

! Type symetrie : on en a besoin dans le cas du calcul des gradients
!     par moindres carres etendu avec extrapolation du gradient au bord
!     La valeur 0 permet de ne pas extrapoler le gradient sur les faces.
!     Habituellement, on evite l'extrapolation sur les faces de symetries
!     pour ne pas tomber sur une indetermination et une matrice 3*3 non
!     inversible dans les configurations 2D).
do ifac = 1, nfabor
  isympa(ifac) = 0
enddo

! Old mass flux. We try not to do the same operation multiple times
! (for shared mass fluxes), without doing too complex tests.

call field_get_n_fields(nfld)

ifmaip = -1
bfmaip = -1

do ii = 1, nfld

  iflid = ii - 1

  call field_get_key_int(iflid, kimasf, iflmas) ! interior mass flux
  call field_get_key_int(iflid, kbmasf, iflmab) ! boundary mass flux

  if (iflmas.ge.0 .and. iflmas.ne.ifmaip) then
    call field_current_to_previous(iflid)
    ifmaip = iflmas
  endif

  if (iflmab.ge.0 .and. iflmab.ne.bfmaip) then
    call field_current_to_previous(iflid)
    bfmaip = iflmab
  endif

enddo

!===============================================================================
! 8.  INITIALISATION DES TERMES SOURCES SI EXTRAPOLES
!===============================================================================

!     les termes sources de Navier Stokes
if(isno2t.gt.0) then
  iptsna = ipproc(itsnsa)
  do ii = 1, ndim
    do iel = 1, ncel
      propce(iel,iptsna+ii-1) = 0.d0
    enddo
  enddo
endif

!     les termes sources turbulents
if(isto2t.gt.0) then
  if(itytur.eq.2) jj = 2
  if(itytur.eq.3) jj = 7
  if(iturb.eq.30.or.iturb.eq.31) jj = 7
  if(iturb.eq.32) jj = 8
  if(iturb.eq.50) jj = 4
  if(iturb.eq.60) jj = 2
  if(iturb.eq.70) jj = 1
  iptsta = ipproc(itstua)
  do ii = 1, jj
    do iel = 1, ncel
      propce(iel,iptsta+ii-1) = 0.d0
    enddo
  enddo
endif

!     les termes sources des scalaires
do iis = 1, nscal
  if(isso2t(iis).gt.0) then
    iptsca = ipproc(itssca(iis))
    do iel = 1, ncel
      propce(iel,iptsca) = 0.d0
    enddo
  endif
enddo

!===============================================================================
! 9.  INITIALISATION DES MOYENNES
!===============================================================================

do imom = 1, nbmomt
  do iel = 1, ncel
    propce(iel,ipproc(icmome(imom))) = 0.d0
  enddo
enddo
do ii = 1,  nbdtcm
  do iel = 1, ncel
    propce(iel,ipproc(icdtmo(ii))) = 0.d0
  enddo
enddo
do ii = 1,  nbmomx
  dtcmom(ii) = 0.d0
enddo

!===============================================================================
! 10.  INITIALISATION CONSTANTE DE SMAGORINSKY EN MODELE DYNAMIQUE
!===============================================================================

if(iturb.eq.41) then
  do iel = 1, ncel
    propce(iel,ipproc(ismago)) = 0.d0
  enddo
endif

!===============================================================================
! 11.  INITIALISATION DU NUMERO DE LA FACE DE PAROI 5 LA PLUS PROCHE
!===============================================================================

!     Si IFAPAT existe,
!     on suppose qu'il faut le (re)calculer : on init le tab a -1.

if(abs(icdpar).eq.2) then
  do iel = 1, ncel
    ifapat(iel) = -1
  enddo
endif

!===============================================================================
! 12.  INITIALISATION DE LA FORCE EXTERIEURE QUAND IPHYDR=1
!===============================================================================

if(iphydr.eq.1) then
  do iel = 1, ncel
    frcxt(1,iel) = 0.d0
    frcxt(2,iel) = 0.d0
    frcxt(3,iel) = 0.d0
  enddo
endif

!===============================================================================
! 13.  INITIALISATION DE LA PRESSION HYDROSTATIQUE QUAND IPHYDR=2
!===============================================================================

if(iphydr.eq.2) then
  do iel = 1, ncel
    prhyd(iel) = 0.d0
  enddo
endif

!===============================================================================
! 14.  INITIALISATIONS EN ALE OU MAILLAGE MOBILE
!===============================================================================

if (iale.eq.1) then
  do ii = 1, nnod
    impale(ii) = 0
    do idim = 1, 3
      depale(idim,ii) = 0.d0
    enddo
  enddo
endif

if (iale.eq.1.or.imobil.eq.1) then
  do ii = 1, nnod
    do idim = 1, 3
      xyzno0(idim,ii) = xyznod(idim,ii)
    enddo
  enddo
endif

!----
! FIN
!----

return
end subroutine
