!------------------------------------------------------------------------------------!
! TITAN - Time-dependent Transport and Angular momentum properties of Nanostructures !
!------------------------------------------------------------------------------------!
!
! MODULE: mod_polyBasis
!
!> @author
!> Jens Renè Suckert, PGI-1/IAS-1, Peter-Grünberg-Institut,FZ Jülich
!
! DESCRIPTION:
!> Read file 'basis' and set up polyatomic basis
!
! REVISION HISTORY:
! 05 July 2017 - Initial Version
!------------------------------------------------------------------------------------!

module mod_polyBasis
  use mod_f90_kind, only: double
  implicit none

contains

  !! Reading basis file 'filename' 
  !! (also used to read original lattice for mod_initial_expectation)
  subroutine read_basis(filename, s)
    use mod_system,    only: System
    use mod_mpi_pars,  only: myrank,abortProgram
    use mod_constants, only: tpi
    use mod_tools,     only: cross, vec_norm
    use mod_io,        only: log_warning
    implicit none

    character(len=*), intent(in)    :: filename
    type(System),     intent(inout) :: s

    integer, parameter :: line_length = 300, word_length = 50, max_elements = 50
    integer :: i, j, k, l
    integer :: f_unit = 99, ios
    character(len=word_length), dimension(max_elements) :: str_arr
    character(len=line_length) :: line
    character(len=1)           :: coord_type
    integer, dimension(50)     :: type_count
    real(double), dimension(3) :: zdir, ydir

    open(unit = f_unit, file=trim(filename), status='old', iostat = ios)
    if((ios /= 0).and.(myrank==0)) call abortProgram("[read_basis] Error reading " // trim(filename))

    ! Reading name
    read(f_unit, fmt='(A)', iostat=ios) s%Name
    s%Name = trim(adjustl(s%Name))

    ! Reading lattice parameter a0
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) s%a0

    ! Reading first Bravais vector (in units of a0), and multiplying by a0
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) (s%a1(i), i=1,3)
    if((vec_norm(s%a1,3) <= 1.d-9).and.(myrank==0)) call abortProgram("[read_basis] a1 not given properly in '" // trim(filename) // "'!")
    s%a1 = s%a1 * s%a0

    ! Reading second Bravais vector (in units of a0), and multiplying by a0
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) (s%a2(i), i=1,3)
    s%a2 = s%a2 * s%a0

    ! Reading third Bravais vector (in units of a0), and multiplying by a0
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) (s%a3(i), i=1,3)
    s%a3 = s%a3 * s%a0

    ! Counting number elements
    str_arr = ""
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) (str_arr(i), i = 1, max_elements)
    do i = 1, max_elements
      if(len_trim(str_arr(i)) == 0 .or. len_trim(str_arr(i)) == word_length) cycle
      s%nTypes = s%nTypes + 1
    end do

    ! Reading name of elements
    allocate(s%Types(s%nTypes))
    j = 1
    do i = 1, max_elements
      if(len_trim(str_arr(i)) == 0 .or. len_trim(str_arr(i)) == word_length) cycle
      s%Types(j)%Name = str_arr(i)

      j = j + 1
    end do

    ! Reading quantity of each element
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) (type_count(i), i = 1, s%nTypes)

    ! Reading units of coordinates
    read(f_unit, fmt='(A)', iostat=ios) line
    read(unit=line, fmt=*, iostat=ios) coord_type

    ! Testing if total number of atoms is correct
    s%nAtoms = sum(type_count(1:s%nTypes))
    if(s%nAtoms <= 0) call abortProgram("[read_basis] No basis atoms given in '" // trim(filename) // "'!")
    allocate(s%Basis(s%nAtoms))

    ! Reading list of atoms in the unit cell and multiplying by the correct units
    k = 0
    do i = 1, s%nTypes
      do j = 1, type_count(i)
        line = ""
        do while(len_trim(line) == 0 .or. len_trim(line) == 200)
          read(f_unit, fmt='(A)', iostat=ios) line
          if((ios /= 0).and.(myrank==0)) &
            call abortProgram("[read_basis] Not enough basis atoms given in '" // trim(filename) // "'!")
        end do
        k = k + 1
        s%Basis(k)%Material = i
        read(unit=line, fmt=*, iostat=ios) (s%Basis(k)%Position(l), l=1,3)
        if(coord_type == 'C' .or. coord_type == 'c' .or. coord_type == 'K' .or. coord_type == 'k') then
          ! Positions of atoms given in Cartesian coordinates
          s%Basis(k)%Position = s%Basis(k)%Position * s%a0
        else
          ! Position of atoms given in Bravais (or Direct, Internal, Lattice) coordinates
          if((vec_norm(s%a2,3) <= 1.d-9).and.(myrank==0)) &
            call log_warning("read_basis", "a2 not given in '" // trim(filename) // "', while Bravais used for atom positions!")
          if((vec_norm(s%a3,3) <= 1.d-9).and.(myrank==0)) &
            call log_warning("read_basis", "a3 not given in '" // trim(filename) // "', while Bravais used for atom positions!")
          s%Basis(k)%Position = s%Basis(k)%Position(1) * s%a1 + s%Basis(k)%Position(2) * s%a2 + s%Basis(k)%Position(3) * s%a3
        end if
      end do
    end do

    ! Calculating volume of BZ and reciprocal lattice vectors
    if((vec_norm(s%a2,3) <= 1.d-9).and.(vec_norm(s%a3,3) <= 1.d-9)) then
      zdir  = [0.d0,0.d0,1.d0]
      ydir  = [0.d0,1.d0,0.d0]
      s%vol = tpi / dot_product(zdir, cross(s%a1,ydir))
      s%b1  = s%vol * cross(zdir,ydir)
      s%b2  = 0.d0
      s%b3  = 0.d0
    else if(vec_norm(s%a3,3) <= 1.d-9) then
      zdir  = [0.d0,0.d0,1.d0]
      s%vol = tpi / dot_product(zdir, cross(s%a1,s%a2))
      s%b1  = s%vol * cross(s%a1,zdir)
      s%b2  = s%vol * cross(zdir,s%a2)
      s%b3  = 0.d0
    else
      s%vol = tpi / dot_product(s%a1, cross(s%a2,s%a3))
      s%b1  = s%vol * cross(s%a2, s%a3)
      s%b2  = s%vol * cross(s%a3, s%a1)
      s%b3  = s%vol * cross(s%a1, s%a2)
    end if

    close(f_unit)
    ! write(unit=out_unit, fmt=*) ""
    ! write(unit=out_unit, fmt=*) "|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|"
    ! write(unit=out_unit, fmt=*) "|     /     -     \    Reading Lattice basis    /     -     \     |"
    ! write(unit=out_unit, fmt=*) "|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|"
    ! write(unit=out_unit, fmt=*) ""
    ! write(unit=out_unit, fmt=*) "System Name: ", trim(s%Name)
    ! write(unit=out_unit, fmt=*) "Number of Atoms: ", s%nAtoms
    ! write(unit=out_unit, fmt=*) "a0: ", s%a0
    ! write(unit=out_unit, fmt=*) "a1: ", s%a1
    ! write(unit=out_unit, fmt=*) "a2: ", s%a2
    ! write(unit=out_unit, fmt=*) "a3: ", s%a3
    ! write(unit=out_unit, fmt=*) "Types: ", (trim(s%Types(i)%Name), i = 1, s%nTypes)
    ! write(unit=out_unit, fmt=*) "Type Count: ", (type_count(i), i = 1, s%nTypes)
    ! write(unit=out_unit, fmt=*) "Number of Types: ", s%nTypes
    ! write(unit=out_unit, fmt=*) "Coordinates Type: ", coord_type
    ! do i = 1, s%nAtoms
    !   write(unit=out_unit, fmt=*) trim(s%Types(s%Basis(i)%Material)%Name), s%Basis(i)%Position
    ! end do
    ! write(unit=out_unit, fmt=*) ""
    ! write(unit=out_unit, fmt=*) "|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|"
    ! write(unit=out_unit, fmt=*) "|-----|-----|-----|  End Reading Lattice basis  |-----|-----|-----|"
    ! write(unit=out_unit, fmt=*) "|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|"
    ! write(unit=out_unit, fmt=*) ""
  end subroutine read_basis

end module mod_polyBasis
