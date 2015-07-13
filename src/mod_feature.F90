!> @brief   This module contains some usefull functions for the detection of continuous features
module mod_feature
    use fplus_list
    use fplus_error
    implicit none
    private

    public :: detect_features_intern

    ! a representation of a point, features are build out of points
    type, public :: point
        integer :: x, y
        real(kind=8) :: value = 0.0
    end type

    ! a feature
    type, public :: feature
        type(list) :: points
    contains
        !> @brief   The smallest distance between a feature and a point measured in grid points
        generic, public :: smallest_grid_dist => feature_smallest_grid_dist_to_point, feature_smallest_grid_dist_to_feature
        procedure, private :: feature_smallest_grid_dist_to_point
        procedure, private :: feature_smallest_grid_dist_to_feature
        !> @brief   Merge another feature into this feature.
        procedure, public :: merge_with_feature => feature_merge_with_feature
        !> @brief   Get the center position of the feature
        procedure, public :: get_center => feature_get_center
    end type

contains

    !> @brief       detect grid points that belong together within one feature
    !> @param[in]   indata          the input data array, 0=no feature, 1=feature
    !> @param[out]  res             (feature_index, feature_size(stored at center point), nx, ny) 
    !> @param[in]   fill_value      value used to indicate missing values in the input array and output array
    subroutine detect_features_intern(indata, res, threshold, fill_value)
        real, dimension(:,:), intent(in) :: indata
        real, dimension(:,:), intent(inout) :: res
        real, intent(in) :: threshold, fill_value

        ! a pointer to a new feature
        class(feature), pointer :: afeature => null()
        class(feature), pointer :: afeature2 => null()
        ! a point that can be copied into a new feature
        type(point) :: apoint
        class(point), pointer :: pointptr
        ! loop variables
        integer :: lo, la, i, j
        ! distance between feature and point
        real :: fp_dist, fp_dist2, ff_dist
        ! the minimal number of points in one feature
        integer :: min_points
        ! the shapes of input and output data
        integer, dimension(2) :: in_shape
        integer, dimension(3) :: out_shape
        ! list of all features
        type(list) :: features
        class(*), pointer :: temp

        ! some settings
        min_points = 1   

        ! create an empty list for all features
        res = 0.0
        features = new_list()
        ! loop over all grid points
        do lo = 1, size(indata,1)
            do la = 1, size(indata,2)
                if (indata(lo,la) == fill_value) then
                    res(lo,la) = fill_value
                    cycle
                end if
                ! this point belongs to a feature
                if (indata(lo,la) > threshold) then
                    ! create a new point from this coordinates
                    apoint = point(lo, la, indata(lo,la))
                    ! ceate the first feature if not already done
                    if (features%length() == 0) then
                        afeature => new_feature(apoint)
                        call features%add(afeature)
                        cycle
                    end if
                    ! there are already some features in the list, is there one with a small enough distance?
                    ! loop over all known features
                    fp_dist = 1.0 *10**6
                    do i = 1, features%length()
                        temp => features%get(i)
                        afeature => dynamic_cast<type(feature),pointer>(temp)
                        fp_dist2 = afeature%smallest_grid_dist(apoint)
                        if (fp_dist > fp_dist2) then
                            fp_dist = fp_dist2
                            j = i
                        end if
                    end do
                    ! add the point to the next feature, if the distance is small enough, else create a new feature
                    if (fp_dist <= 1) then
                        temp => features%get(j)
                        afeature => dynamic_cast<type(feature),pointer>(temp)
                        call afeature%points%add(apoint, copy=.true.)
                    else
                        afeature => new_feature(apoint)
                        call features%add(afeature)
                    end if
                end if
            end do
        end do

        ! merge feature that are located close together
        do i = features%length(), 2, -1
            temp => features%get(i)
            afeature => dynamic_cast<type(feature), pointer>(temp)
            do j = i-1, 1, -1
                temp => features%get(j)
                afeature2 => dynamic_cast<type(feature), pointer>(temp)
                ! calculate the smallest distance between both features and merge them if close enough together
                if (afeature%smallest_grid_dist(afeature2) < 2) then
                    ! merge the feature at index i into the feature at index j
                    call afeature2%merge_with_feature(afeature)
                    ! remove the feature at index i
                    call afeature%points%clear()
                    call features%remove(i)
                    deallocate(afeature)
                    ! exit the loop, one feature can only be merged ones
                    exit
                end if
            end do
        end do

        ! remove features, that are to small
        do i = features%length(), 1, -1
            temp => features%get(i)
            afeature => dynamic_cast<type(feature), pointer>(temp)
            if (afeature%points%length() < min_points) then
                call afeature%points%clear()
                call features%remove(i)
                deallocate(afeature)
            end if
        end do

        ! write the detected features to the result array
        do i = 1, features%length()
            temp => features%get(i)
            afeature => dynamic_cast<type(feature), pointer>(temp)
            ! loop over all points in the feature
            do j = 1, afeature%points%length()
                temp => afeature%points%get(j)
                pointptr => dynamic_cast<type(point), pointer>(temp)
                ! store all features in the first dimension
                res(pointptr%x, pointptr%y) = i
            end do
            ! cleanup points
            call afeature%points%clear()
        end do

        ! cleanup the feature list
        call features%clear(dealloc_all=.true.)
    end subroutine

    ! create a new feature from its first point
    function new_feature(p) result(res)
        class(point), intent(in) :: p
        class(feature), pointer :: res

        ! allocate the feature
        allocate(res)

        ! create the list of points
        res%points = new_list()

        ! add the first point
        call res%points%add(p, copy=.true.)
    end function

    !> @brief   calculates the distance in grid points between a feature a point
    function feature_smallest_grid_dist_to_point(this, p) result (res)
        class(feature), intent(in) :: this
        class(point), intent(in) :: p
        real (kind=8) :: res

        ! local variables
        real (kind=8) :: dist2
        integer :: i
        type(point), pointer :: p2
        class(*), pointer :: temp
        res = 1.0 * 10**6

        ! loop over all points
        do i = 1, this%points%length()
            temp => this%points%get(i)
            p2 => dynamic_cast<type(point), pointer>(temp)
            dist2 = grid_dist(p2, p)
            if (dist2 < res) res = dist2
        end do
    end function

    !> @brief   calculates the distance between a feature a another feature
    function feature_smallest_grid_dist_to_feature(this, f) result (res)
        class(feature), intent(in) :: this
        class(feature), intent(in) :: f
        real (kind=8) :: res

        ! local variables
        real (kind=8) :: dist2
        integer :: i, j
        type(point), pointer :: p1, p2
        class(*), pointer :: temp
        res = 1.0 * 10**6

        ! loop over all points
        do i = 1, this%points%length()
            temp => this%points%get(i)
            p1 => dynamic_cast<type(point), pointer>(temp)
            do j = 1, f%points%length()
                temp => f%points%get(j)
                p2 => dynamic_cast<type(point), pointer>(temp)
                dist2 = grid_dist(p1, p2)
                if (dist2 < res) res = dist2
            end do
        end do
    end function

    !> @brief       Merge another feature into this feature.
    subroutine feature_merge_with_feature(this, another_feature)
        class(feature) :: this
        class(feature) :: another_feature
        ! local variables
        integer :: i
        ! loop over all points from another feature
        do i = 1, another_feature%points%length()
            call this%points%add(another_feature%points%get(i), copy=.true.)
        end do
    end subroutine

    !> @brief   Get the center position of the feature
    function feature_get_center(this) result (res)
        class (feature) :: this
        type(point) :: res

        ! local variables
        class(point), pointer :: pointptr
        integer :: j
        class(*), pointer :: temp

        ! init the result
        res = point(0,0,0)

        ! loop over all points
        do j = 1, this%points%length()
            temp => this%points%get(j)
            pointptr => dynamic_cast<type(point), pointer>(temp)
            res%x = res%x + pointptr%x
            res%y = res%y + pointptr%y            
        end do

        ! devide by the number of points
        if (this%points%length() == 0) call fplus_error_print("an empty feature has no center!", "feature%get_center()")
        res%x = nint(real(res%x) / this%points%length())
        res%y = nint(real(res%y) / this%points%length())       
    end function

    !> @brief   The distance between two points measured in grib points
    function grid_dist(p1, p2) result (res)
        real(kind=8) :: res
        class(point), intent(in) :: p1, p2
        res = sqrt(real(p2%x-p1%x)**2+real(p2%y-p1%y)**2)
    end function

    subroutine print_point(p)
        class(point), intent(in) :: p
        print*, "x=", p%x, " y=", p%y
    end subroutine

end module mod_feature
