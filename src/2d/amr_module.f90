!> The module contains the definition of a "node descriptor" 
!! as well as other global variables used during the whole run.
!! 
!! The "node descriptor" is a tree data structure we use to keep track of 
!! all AMR grids.
!! Each grid in the grid hierarchy corresponds to a node in the tree. 
!! When a fine grid is nested in a coarse grid, its corresponding node in the tree 
!! is an offspring of the parent node corresponding to the coarse grid.
!! ![Tree data structure for grid management](AMR_tree.png "amr_tree")
!!
!! Each node has a fixed number of items of information describing the grid,
!! stored and accessable as **node(property number, node number)** (which returns
!! a integer type as either data itself or a pointer to a memory location)
!! and **rnode(property number, node number)** (which returns a real type).
!! E.g. **node(nestlevel, 5)** stores AMR level of grid 5.
!! **rnode(cornxlo, 3)** stores x-coordinate of left border of grid 3.
!!
!! See explanation to each data members in this module 
!! for details of all properties of a node.
!!
module amr_module

    implicit none
       
    save
       
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ! :::::   data structure info.
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    integer, parameter :: rsize = 5
    integer, parameter :: nsize = 19

    !  :::::::   integer part of node descriptor
    !> node number (index) of next grid on the same level
    integer, parameter :: levelptr  = 1 

    !> temporary pointer
    integer, parameter :: tempptr   = 2

    ! TODO
    integer, parameter :: errptr    = 3

    !> AMR level of the grid
    integer, parameter :: nestlevel = 4

    ! TODO
    integer, parameter :: cfluxptr  = 5

    !> pointer to the address of memory storing fluxes in a layer around the grid, 
    !! to be used in conservation fixup near coarse-fine grid intersections.
    !! The memory allocated is 
    !! \f$ 2 \times nvar \times lenbc + naux \times lenbc \f$, 
    !! where \f$lenbc\f$ is 
    !! the number of its parent grid cells adjacent to (around) their boundary interfaces. 
    !! The coefficient 2 is for two spaces. 
    !! One is for plus or minus fluxes, and the other is for the coarse solution for wave fixing.
    ! TODO
    integer, parameter :: ffluxptr  = 6

    !> pointer to the address of memory storing the first copy of solution data on this grid
    ! TODO
    integer, parameter :: store1    = 7

    !> pointer to the address of memory storing the second copy of solution data on this grid
    integer, parameter :: store2    = 8

    !> global *i* index of left border of this grid
    integer, parameter :: ndilo     = 9

    !> global *i* index of right border of this grid
    integer, parameter :: ndihi     = 10

    !> global *j* index of lower border of this grid
    integer, parameter :: ndjlo     = 11

    !> global *j* index of upper border of this grid
    integer, parameter :: ndjhi     = 12

    !> pointer to the address of memory storing auxiliary data on this grid
    integer, parameter :: storeaux  = 13

    !> pointer to the address of memory storing flags for refinement on this grid
    integer, parameter :: storeflags  = 14

    !> number of flagged cells on this grid
    integer, parameter :: numflags  = 15

    !> domain flags, indexed within base level (lbase) index space
    integer, parameter :: domflags_base  = 16

    !> domain flags, indexed within level-of-this-grid level index space
    integer, parameter :: domflags2  = 17

    !> pointer (actually it's an index in the bndList array) to the first node 
    !! of a linked list, which stores all grids (on the same level) that border this grid
    integer, parameter :: bndListSt  = 18

    !> number of grids (on the same level) that border this grid
    integer, parameter :: bndListNum = 19

    ! :::::::  real part of node descriptor
    !> x-coordinate of the left border of this grid
    integer, parameter :: cornxlo  = 1
    !> y-coordinate of the lower border of this grid
    integer, parameter :: cornylo  = 2
    !> x-coordinate of the right border of this grid
    integer, parameter :: cornxhi  = 3
    !> y-coordinate of the upper border of this grid
    integer, parameter :: cornyhi  = 4
    !> current simulation time on this grid
    integer, parameter :: timemult = 5

    ! :::::::   for linking nodes
    integer, parameter :: nextfree = 2
    integer, parameter :: null = 0
    integer, parameter :: nil  = 0

    integer, parameter :: gridNbor = 1 !use 1st col, 2nd col is nextfree - the link

    ! :::::::  for flagging points   
    ! TODO: can use one bit for this instead of real?
    ! needs no refine
    real(kind=8), parameter :: goodpt = 0.0
    ! needs refine
    real(kind=8), parameter :: badpt  = 2.0
    real(kind=8), parameter :: badpro = 3.0

    real(kind=8), parameter :: NEEDS_TO_BE_SET = 10.e33
    real(kind=8), parameter :: rinfinity = 10.e32
    integer, parameter :: iinfinity = 999999999
    integer, parameter :: horizontal = 1
    integer, parameter :: vertical = 2
    integer, parameter :: maxgr = 15000
    integer, parameter :: maxlv = 10

    !> maximum number of clusters (grids) on each grid level
    integer, parameter :: maxcl = 5000

    ! The max1d parameter should be changed if using OpenMP grid based 
    ! looping, usually set to max1d = 60
    integer, parameter :: max1d = 60 

    integer, parameter :: maxvar = 10
    integer, parameter :: maxaux = 20
    integer, parameter :: maxwave = 10


    ! note use of sentinel in listStart
    integer :: listOfGrids(maxgr),listStart(0:maxlv+1)
    integer,parameter :: bndListSize = 8*maxgr
    integer :: bndList(bndListSize,2)  ! guess size, average # nbors 4? manage as linked list

    real(kind=8) hxposs(maxlv), hyposs(maxlv),possk(maxlv),rnode(rsize, maxgr) 



    real(kind=8) tol, tolsp
    integer ibuff,  mstart, ndfree, ndfree_bnd, lfine, node(nsize, maxgr), &
            icheck(maxlv),lstart(maxlv),newstl(maxlv), &
            listsp(maxlv),intratx(maxlv),intraty(maxlv), &
            kratio(maxlv), iregsz(maxlv),jregsz(maxlv), &
            iregst(maxlv),jregst(maxlv), &
            iregend(maxlv),jregend(maxlv), &
            numgrids(maxlv),numcells(maxlv), &
            iorder,mxnest,kcheck

    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ! ::::  for alloc array/memory
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    ! Static memory implementation
    ! parameter  (memsize = 10000000)
    ! common  /calloc/   alloc(memsize)

    ! Dynamic memory: 
    !real(kind=8), allocatable, target, dimension(:) :: storage
    !real(kind=8), pointer, dimension(:) :: alloc   ! old way, changed mjb Sept. 2014
    real(kind=8), allocatable, dimension(:) :: alloc    ! new way, use allocatable, not pointer
    integer memsize
       
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::\
    ! :::::   for space management of alloc array
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    integer, parameter :: lfdim=5000
    integer lfree(lfdim,2),lenf

    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ! :::::  domain description variables
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    logical xperdom, yperdom, spheredom
    real(kind=8) :: xupper, yupper, xlower, ylower
    integer :: nghost, mthbc(4)

    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ! :::::  collect stats
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    real(kind=8)  rvoll(maxlv),evol,rvol,avenumgrids(maxlv)
    integer ::  iregridcount(maxlv), tvoll(maxlv)
    integer :: timeRegridding, timeUpdating, timeValout
    integer :: timeFlglvl,timeGrdfit2,timeGrdfit3,timeGrdfitAll
    integer :: timeBound,timeStepgrid
    integer :: timeFlagger, timeBufnst,timeTick
    real(kind=8) tvollCPU(maxlv), timeTickCPU
    real(kind=8) timeBoundCPU,timeStepgridCPU,timeRegriddingCPU
    real(kind=8) timeValoutCPU

    integer lentot,lenmax,lendim

    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ! :::::  method parameters
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    character(len=10), allocatable :: auxtype(:)
    integer  method(7), mwaves, mcapa, dimensional_split
    integer, allocatable :: mthlim(:)
    real(kind=8) cfl,cflmax,cflv1,cfl_level

    logical :: use_fwaves
    logical :: flag_richardson,flag_gradient
    integer :: verbosity_regrid

    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    ! ::::: Parameters and variables related to I/O and checkpointing
    ! ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    logical    printout,matlabout,ncarout

    ! variables for conservation checking:
    real(kind=8) tmass0

    ! variables for specifying output format
    integer :: output_style, nstop, nout, iout
    real(kind=8), allocatable :: tout(:)
    real(kind=8) :: t0, tfinal
    real(kind=8) :: tstart_thisrun  ! /= t0 in case of restart
    integer :: nq_components, naux_components, output_format
    integer, allocatable :: output_q_components(:)
    integer, allocatable :: output_aux_components(:)
    logical :: output_aux_onlyonce

    ! checkpointing:
    integer :: checkpt_style, nchkpt, checkpt_interval
    real(kind=8), allocatable :: tchk(:)

    integer :: matlabu

    !  USE UNITS NUMBERS < 89.
    ! 89 and + numthreads taken by gauge output
    integer, parameter :: parmunit = 12
    integer, parameter :: chkunit = 10
    integer, parameter :: inunit  = 5
    integer, parameter :: outunit = 66
    integer, parameter :: pltunit1 = 3
    integer, parameter :: rstunit = 9
    integer, parameter :: dbugunit = 11
    integer, parameter :: matunit = 70

    ! ::::  Debugging flags (verbose output)
    logical &
                dprint,     & !  domain flags output
                eprint,     & !  error estimation output
                edebug,     & !  even more error estimation output
                gprint,     & !  verbose grid generation (clustering,colating...)
                nprint,     & !  nestck reporting
                pprint,     & !  projec tagged pts.
                rprint,     & !  regridding -  summary of new grids
                sprint,     & !  space (memory) output
                tprint,     & !  tick (time stepping) reporting
                uprint        !  updating/upbnding reporting


    ! Restart file name:
    character(len=200) :: rstfile
    logical :: check_a

end module amr_module
