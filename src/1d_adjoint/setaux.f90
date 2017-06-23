subroutine setaux(mbc,mx,xlower,dx,maux,aux)

    ! Called at start of computation before calling qinit, and
    ! when AMR is used, also called every time a new grid patch is created.
    ! Use to set auxiliary arrays aux(1:maux, 1-mbc:mx+mbc, 1-mbc:my+mbc).
    ! Note that ghost cell values may need to be set if the aux arrays
    ! are used by the Riemann solver(s).
    !
    ! This default version does nothing. 

    use amr_module, only : NEEDS_TO_BE_SET
    use adjoint_module, only: innerprod_index

    integer, intent(in) :: mbc,mx,maux
    real(kind=8), intent(in) :: xlower,dx
    real(kind=8), intent(out) ::  aux(maux,1-mbc:mx+mbc)
    integer :: ii,iint

    ! If a new grid has been created, but hadn't been flagged
    ! set innerproduct to zero.
    do ii=1-mbc,mx+mbc
        if (aux(innerprod_index,ii) .eq. NEEDS_TO_BE_SET) then
            aux(innerprod_index,ii) = 0.d0
        endif
    enddo
end subroutine setaux