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

! Module for dimensions

module dimens

  !=============================================================================

  ! Mesh and field data

  !=============================================================================

  integer, save :: ncelet, ncel, nfac, nfabor, ncelbr,   &
                   nprfml, nfml, nnod, lndfac, lndfbr

  integer, save :: ndim

  integer, save :: nvar, nscal, nvisls, nphas

  integer, save :: ncofab

  integer, save :: nproce, nprofa, nprofb, nfluma

  ! Fake dimension for arrays propfb, coefa and coefb
  ! where nfabor = 0 (to avoid issues with array bounds when
  ! multidimensional arrays have size nfabor in one dimension)

  integer, save :: ndimfb

  !=============================================================================

end module dimens
