!     
! File:   ncl_feature.f90
! Author: Robert Redl
!
! Created on 13. Juli 2015, 09:59
!
! this is a wrapper for the usage of the module procedure detect_features_intern
subroutine detect_features(nx, ny, indata, res, fill_value)
    use mod_feature
    integer :: nx, ny
    real, dimension(nx,ny) :: indata
    real, dimension(nx,ny,3) :: res
    real :: fill_value

    ! call the module procedure 
    call detect_features_intern(indata, res, fill_value)
end subroutine
