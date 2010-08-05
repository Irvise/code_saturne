!-------------------------------------------------------------------------------

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

! Module for fuel combustion

module fuincl

  !=============================================================================

  use ppppar
  use ppthch

  !=============================================================================

  !      EPSIFL : Precision pour les tests

  double precision epsifl
  parameter ( epsifl = 1.d-8 )

  !--> DONNEES RELATIVES AU FUEL

  !      - Proprietes du fuel
  !        CFOL      --> fractions massiques elementaires en C, H, O, S, In (%)
  !        HFOL          du fuel oil liquid
  !        OFOL
  !        SFOL
  !        XInFOL
  !        PCIFOL    --> PCI (J/kg) fuel oil liquid
  !        RHO0FL   --> Masse volumique initiale (kg/m3)
  !      - Proprietes du coke
  !        CKF      --> Fractions massiques elementaires en C, H, O, S, In (%)
  !        HKF          du coke
  !        OKF
  !        SKF
  !        XInKF
  !        GAMMA    --> Composition du coke
  !        DELTA        sous la forme CH(GAMMA)O(DELTA)
  !                         GAMMA = HCK/CCK
  !                         DELTA = OCK/CCK
  !        PCIKF     --> PCI (J/kg) coke
  !        RHOKF     --> Masse volumique coke
  !        FKC       --> Fraction massique initiale de coke dans le fuel
  !        H02FOL    --> H0 du fuel oil liquid
  !        CPFOL     --> CP du fuel oil liquid
  !        HRFVAP    --> H formation vapeur a Tebu
  !        Fractions massiques dans les vapeurs
  !        HSFOV     --> H2S
  !        COFOV     --> CO
  !        CHFOV     --> CHn
  !        nHCFOV    --> n dans la formule CHn (un reel, car formule molaire moyenne)

  !        DFOL      --> densite du fuel liquide

  double precision, save :: cfol , hfol , ofol , sfol, xinfol,               &
                            pcifol , rho0fl , rhokf,                         &
                            h02fol , cp2fol , hrfvap, dfol,                  &
                            ckf , hkf , okf , skf, xinkf, pcikf, fkc,        &
                            hsfov, cofov, chfov, nhcfov

  !      - Parametres pour l'evaporation
  !      TEVAP1      --> temperature de debut d'evaporation
  !      TEVAP2      --> temperature de fin d'evaporation

  !        - Parametres cinetiques pour la combustion heterogene du coke
  !          (Modele a sphere retrecissante)
  !        AHETFL   --> Constante pre-exponentielle (kg/m2/s/atm)
  !        EHETFL   --> Energie d'activation (kcal/mol)
  !        IOFHET   --> Ordre de la reaction 0.5 si = 0 1 si = 1

  double precision, save :: yfol , afol  , efol  ,                           &
                            ahetfl , ehetfl, tevap1, tevap2
  integer, save ::          iofhet

  !      - Enthalpie du fuel et coke
  !     IFOL         --> Pointeur dans le tableau EHSOLI pour
  !                         le fuel oil liquid
  !     IKF          --> Pointeur dans le tableau EHSOLI pour
  !                         le Coke
  !     EHSOLI(S,IT) --> Enthalpie massique (J/kg) du constituant solide
  !                         no S a la temperature T(IT)

  integer, save ::          ifol, ikf

  ! ---- PAR CLASSES (grandeurs deduites)

  !        NCLAFU     --> Nb de classes

  integer, save ::          nclafu

  !      - Proprietes : on garde le meme max que pour le charbon qui
  !        est definis dans ppppar.h
  !        DINIFL(CL)  --> Diametre initial (mm)
  !        DINIKF(CL)  --> Diametre coke (mm)
  !        DINIIN(CL)  --> Diametre min (mm)

  double precision, save :: dinifl(nclcpm),dinikf(nclcpm),diniin(nclcpm)

  !--> DONNEES RELATIVES A LA COMBUSTION DES ESPECES GAZEUSES

  !        IIFOV        --> Pointeur FOV   pour EHGAZE et WMOLE
  !        IICO         --> Pointeur CO    pour EHGAZE et WMOLE
  !        IIO2         --> Pointeur O2    pour EHGAZE et WMOLE
  !        IICO2        --> Pointeur CO2   pour EHGAZE et WMOLE
  !        IIH2O        --> Pointeur H2O   pour EHGAZE et WMOLE
  !        IIN2         --> Pointeur N2    pour EHGAZE et WMOLE
  !        IIH2S        --> Pointeur H2S   pour EHGAZE et WMOLE
  !        IISO2        --> Pointeur SO2   pour EHGAZE et WMOLE

  !        XSI         --> XSI = 3,76 pour de l'air
  !        FVAPMX     --> Maximum pour le traceur F3
  !        FOV         --> Composition de l'hydrocarbure relatif
  !                        aux matieres volatiles
  !        A,     --> Coefficients stoechiometriques molaires pour
  !        B          la reaction d'evaporation

  !        Concentrations dans les especes globales
  !        AFOVF1         nb de moles de vapeur associees a un kg de traceur 1
  !        ACOF1                          CO
  !        AH2SF1                         H2S
  !        AH2SF3                         H2S
  !        AH2OF3                         H2O
  !        FF3MAX fraction massqique maximale du traceur F3
  !               (correspondant a la masse liberee par combustion heterogene il
  !                ne peut exister pur)

  double precision, save ::  fvapmx, fov, a, b
  integer, save ::           ifov,ih2s,iso2

  !--> DONNEES COMPLEMENTAIRES RELATIVES AU CALCUL DE RHO
  !    SUR LES FACETTES DE BORD

  !       IENTAT(IENT) --> Indicateur air par type de facette d'entree
  !       IENTFL(IENT) --> Indicateur CFOL  par type de facette d'entree
  !       TIMPAT(IENT) --> Temperature en K pour l'air relative
  !                         a l'entree IENT

  integer, save ::          ientfl(nozppm)

  !--> POINTEURS DANS LE TABLEAU TBMCR

  double precision, save :: afovf1,acof1,ah2sf1,ah2sf3
  double precision, save :: ff3max

  !--> GRANDEURS FOURNIES PAR L'UTILISATEUR EN CONDITIONS AUX LIMITES
  !      PERMETTANT DE CALCULER AUTOMATIQUEMENT LA VITESSE, LA TURBULENCE,
  !      L'ENTHALPIE D'ENTREE.

  !    POUR LES ENTREES UNIQUEMENT , IENT ETANT LE NUMERO DE ZONE FRONTIERE

  !       QIMPFL(IENT)      --> Debit      Fuel Oil Liquid     en kg/s
  !       TIMPFL(IENT)      --> Temperature  FOL               en K

  double precision, save ::  qimpfl(nozppm), timpfl(nozppm)
  double precision, save ::  distfu(nozppm,nclcpm)
  double precision, save ::  hlfm

  !=============================================================================

end module fuincl
