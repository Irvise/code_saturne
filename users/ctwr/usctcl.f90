!-------------------------------------------------------------------------------

!VERS


!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2009 EDF S.A., France

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

subroutine usctcl &
!================

 ( idbia0 , idbra0 ,                                              &
   ndim   , ncelet , ncel   , nfac   , nfabor , nfml   , nprfml , &
   nnod   , lndfac , lndfbr , ncelbr ,                            &
   nvar   , nscal  , nphas  ,                                     &
   nideve , nrdeve , nituse , nrtuse ,                            &
   ifacel , ifabor , ifmfbr , ifmcel , iprfml , maxelt , lstelt , &
   ipnfac , nodfac , ipnfbr , nodfbr ,                            &
   icodcl , itrifb , itypfb , izfppp ,                            &
   idevel , ituser , ia     ,                                     &
   xyzcen , surfac , surfbo , cdgfac , cdgfbo , xyznod , volume , &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  , rcodcl ,                                     &
   w1     , w2     , w3     , w4     , w5     , w6     , coefu  , &
   rdevel , rtuser , ra     )

!===============================================================================
! FONCTION :
! --------

!    ROUTINE UTILISATEUR POUR PHYSIQUE PARTICULIERE
!            MODELISATION AEROREFRIGERANTS
!    REMPLISSAGE DU TABLEAU DE CONDITIONS AUX LIMITES
!    (ICODCL,RCODCL) POUR LES VARIABLES INCONNUES
!    PENDANT DE USCLIM.F



!    CE SOUS PROGRAMME UTILISATEUR EST OBLIGATOIRE
!    =============================================


! Introduction
! ============

! Here one defines boundary conditions on a per-face basis.

! Boundary faces may be identified using the 'getfbr' subroutine.
! The syntax of this subroutine is described in the 'usclim' subroutine,
! but a more thorough description can be found in the user guide.


! Boundary condition types
! ========================

! Boundary conditions setup for standard variables (pressure, velocity,
! turbulence, scalars) is described precisely in the 'usclim' subroutine.

! Detailed explanation will be found in the theory guide.


!-------------------------------------------------------------------------------
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
! icodcl           ! ia ! --> ! boundary condition code                        !
!  (nfabor, nvar)  !    !     ! = 1  -> Dirichlet                              !
!                  !    !     ! = 2  -> flux density                           !
!                  !    !     ! = 4  -> sliding wall and u.n=0 (velocity)      !
!                  !    !     ! = 5  -> friction and u.n=0 (velocity)          !
!                  !    !     ! = 6  -> roughness and u.n=0 (velocity)         !
!                  !    !     ! = 9  -> free inlet/outlet (velocity)           !
!                  !    !     !         inflowing possibly blocked             !
! itrifb           ! ia ! <-- ! indirection for boundary faces ordering        !
!  (nfabor, nphas) !    !     !                                                !
! itypfb           ! ia ! --> ! boundary face types                            !
!  (nfabor, nphas) !    !     !                                                !
! izfppp           ! te ! --> ! numero de zone de la face de bord              !
! (nfabor)         !    !     !  pour le module phys. part.                    !
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
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! rcodcl           ! ra ! --> ! boundary condition values                      !
!  (nfabor,nvar,3) !    !     ! rcodcl(1) = Dirichlet value                    !
!                  !    !     ! rcodcl(2) = exterior exchange coefficient      !
!                  !    !     !  (infinite if no exchange)                     !
!                  !    !     ! rcodcl(3) = flux density value                 !
!                  !    !     !  (negative for gain) in w/m2 or                !
!                  !    !     !  roughness height (m) if icodcl=6              !
!                  !    !     ! for velocities           ( vistl+visct)*gradu  !
!                  !    !     ! for pressure                         dt*gradp  !
!                  !    !     ! for scalars    cp*(viscls+visct/sigmas)*gradt  !
! w1,2,3,4,5,6     ! ra ! --- ! work arrays                                    !
!  (ncelet)        !    !     !  (computation of pressure gradient)            !
! coefu            ! ra ! --- ! work array                                     !
!  (nfabor, 3)     !    !     !  (computation of pressure gradient)            !
! rdevel(nrdeve)   ! ra ! <-> ! real work array for temporary development      !
! rtuser(nrtuse)   ! ra ! <-> ! user-reserved real work array                  !
! ra(*)            ! ra ! --- ! main real work array                           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use ihmpre
use paramx
use pointe
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use ctincl

!===============================================================================

implicit none

! Arguments

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
integer          icodcl(nfabor,nvar)
integer          itrifb(nfabor,nphas), itypfb(nfabor,nphas)
integer          izfppp(nfabor)
integer          idevel(nideve), ituser(nituse), ia(*)

double precision xyzcen(ndim,ncelet)
double precision surfac(ndim,nfac), surfbo(ndim,nfabor)
double precision cdgfac(ndim,nfac), cdgfbo(ndim,nfabor)
double precision xyznod(ndim,nnod), volume(ncelet)
double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision rcodcl(nfabor,nvar,3)
double precision w1(ncelet),w2(ncelet),w3(ncelet)
double precision w4(ncelet),w5(ncelet),w6(ncelet)
double precision coefu(nfabor,ndim)
double precision rdevel(nrdeve), rtuser(nrtuse), ra(*)

! Local variables

integer          idebia, idebra
integer          ifac, iel, ii, ivar, iphas
integer          ilelt, nlelt, izone

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================
! 0.  CE TEST PERMET A L'UTILISATEUR D'ETRE CERTAIN QUE C'EST
!       SA VERSION DU SOUS PROGRAMME QUI EST UTILISEE
!       ET NON CELLE DE LA BIBLIOTHEQUE
!===============================================================================

if(1.eq.1) then
  write(nfecra,9001)
  call csexit (1)
  !==========
endif

 9001 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET LORS DE L''ENTREE DES COND. LIM.      ',/,&
'@    =========                                               ',/,&
'@         MODULE AEROREFRIGERANTS                            ',/,&
'@     LE SOUS-PROGRAMME UTILISATEUR usctcl DOIT ETRE COMPLETE',/,&
'@                                                            ',/,&
'@     Ce sous-programme utilisateur permet de definir les    ',/,&
'@       conditions aux limites. Il est indispensable.        ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 1.  INITIALISATIONS

!===============================================================================

idebia = idbia0
idebra = idbra0

!===============================================================================
! 2.  REMPLISSAGE DU TABLEAU DES CONDITIONS LIMITES
!       ON BOUCLE SUR LES FACES DE BORD
!         ON DETERMINE LA FAMILLE ET SES PROPRIETES
!           ON IMPOSE LA CONDITION LIMITE

!          IMPOSER ICI LES CONDITIONS LIMITES SUR LES FACES DE BORD

!===============================================================================

!   Pour chaque type de condition relative aux physiques particulieres
!       on affecte un numero de zone de maniere a pouvoir donner les
!       conditions aux limites par zone physique et non par face de maillage
!       Un numero de zone est un entier arbitraire strictement positif
!         et inferieur ou egal a NOZPPM (dont la valeur est fixee en
!         parametre dans ppppar.h)


! --- On impose en couleur 2 une sortie libre pour toutes les phases
CALL GETFBR('2',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

  izone = 1
  izfppp(ifac) = izone

!          SORTIE : FLUX NUL VITESSE ET TEMPERATURE, PRESSION IMPOSEE
!            Noter que la pression sera recalee a P0
!                sur la premiere face de sortie libre (ISOLIB)


  do iphas = 1, nphas
    itypfb(ifac,iphas) = isolib
  enddo

!       On impose un profil de pression sur toutes les faces
  iphas = 1
  icodcl(ifac,ipr(iphas)) = 1
  rcodcl(ifac,ipr(iphas),1) =                                     &
    ro0(iphas)*(  gx*(cdgfbo(1,ifac)-xyzp0(1,iphas))              &
                + gy*(cdgfbo(2,ifac)-xyzp0(2,iphas))              &
                + gz*(cdgfbo(3,ifac)-xyzp0(3,iphas)))

enddo

! --- On impose en couleur 4 une paroi pour toutes les phases
CALL GETFBR('4',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

  izone = 2
  izfppp(ifac) = izone

!          PAROI : DEBIT NUL (FLUX NUL POUR LA PRESSION)
!                  FROTTEMENT POUR LES VITESSES (+GRANDEURS TURB)
!                  FLUX NUL SUR LES SCALAIRES

  do iphas = 1, nphas
   itypfb(ifac,iphas)   = iparoi
  enddo

enddo

! --- On impose une symetrie en couleur 5 pour toutes les phases
CALL GETFBR('5',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

  izone = 3
  izfppp(ifac) = izone

!          SYMETRIES

  do iphas = 1, nphas
    itypfb(ifac,iphas)   = isymet
  enddo

enddo

!----
! FORMATS
!----

!----
! FIN
!----

return
end subroutine
