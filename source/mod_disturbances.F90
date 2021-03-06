module mod_disturbances
  use mod_f90_kind, only: double
  implicit none
  ! Disturbances and renormalized disturbances: chd,sdx,sdy,sdz,ldx,ldy,ldz
  complex(double),allocatable   :: disturbances(:,:)
  !! Disturbances
  complex(double),allocatable   :: total_disturbances(:)
  !! Total Disturbances
  complex(double),allocatable   :: rdisturbances(:,:)
  !! Renormalized disturbances
  complex(double), dimension(:,:),   allocatable :: tchiorbiikl
  !! Full disturbance response function
  complex(double), dimension(:,:,:), allocatable :: ldmat
  !! Angular Momentum Disturbance Matrix
  complex(double),dimension(:),allocatable       :: sdmat
  !! Spin Disturbance Matrix

  character(len=5), dimension(7), parameter, private :: folder = ["CD", "SD", "SD", "SD", "LD", "LD", "LD"]
  character(len=2), dimension(7), parameter, private :: filename = ["Cd", "Sx", "Sy", "Sz", "Lx", "Ly", "Lz"]

contains

  subroutine allocate_disturbances()
  !! This subroutine allocates variables related to the disturbance calculation
    use mod_f90_kind,   only: double
    use mod_parameters, only: renorm,dim,dimspinAtoms
    use mod_System,     only: s => sys
    use mod_mpi_pars, only: abortProgram
    use mod_mpi_pars,   only: rFreq
    implicit none
    integer           :: AllocateStatus

    if(rFreq(1) == 0) then
      allocate( disturbances(7,s%nAtoms),total_disturbances(7),sdmat(dimspinAtoms),ldmat(s%nAtoms,9,9), STAT = AllocateStatus )
      if (AllocateStatus/=0) call abortProgram("[allocate_disturbances] Not enough memory for: disturbances,total_disturbances,dmat,ldmat")

      if(renorm) then
        allocate( rdisturbances(7,s%nAtoms), STAT = AllocateStatus )
        if (AllocateStatus/=0) call abortProgram("[allocate_disturbances] Not enough memory for: rdisturbances")
      end if
    end if

    allocate( tchiorbiikl(dim,4), STAT = AllocateStatus  )
    if (AllocateStatus/=0) call abortProgram("[allocate_disturbances] Not enough memory for: tchiorbiikl")

  end subroutine allocate_disturbances

  subroutine deallocate_disturbances()
  !! This subroutine deallocates variables related to the disturbance calculation
    implicit none

    if(allocated(disturbances)) deallocate(disturbances)
    if(allocated(sdmat)) deallocate(sdmat)
    if(allocated(ldmat)) deallocate(ldmat)
    if(allocated(rdisturbances)) deallocate(rdisturbances)
    if(allocated(tchiorbiikl)) deallocate(tchiorbiikl)

  end subroutine deallocate_disturbances

  subroutine create_disturbance_files()
  !! This subroutine creates all the files needed for the disturbances
    use mod_parameters, only: output, renorm, renormnb
    use mod_mpi_pars
    use mod_system, only: s => sys
    implicit none

    character(len=500)  :: varm
    integer :: i,j,iw

    do j=1,7
      do i=1,s%nAtoms
        iw = 3000+(i-1)*7+j
        write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,'_pos=',i0,a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),filename(j),i,trim(output%Energy),trim(output%info),trim(output%BField),trim(output%SOC),trim(output%EField),trim(output%suffix)
        open (unit=iw, file=varm, status='replace', form='formatted')
        write(unit=iw, fmt="('#     energy    , amplitude of ',a,' , real part of ',a,' , imag part of ',a,' ,  phase of ',a,'  ,  cosine of ',a,'  ,  sine of ',a,'  ')") filename(j),filename(j),filename(j),filename(j),filename(j),filename(j)
        close(unit=iw)
        if(renorm) then
        iw = iw+1000
        write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/r',a,'_pos=',i0,a,a,a,a,a,'_renormnb=',i0,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),filename(j),i,trim(output%Energy),trim(output%info),trim(output%BField),trim(output%SOC),trim(output%EField),renormnb,trim(output%suffix)
        open (unit=iw, file=varm, status='replace', form='formatted')
        write(unit=iw, fmt="('#     energy    , amplitude of ',a,' , real part of ',a,' , imag part of ',a,' ,  phase of ',a,'  ,  cosine of ',a,'  ,  sine of ',a,'  ')") filename(j),filename(j),filename(j),filename(j),filename(j),filename(j)
        close(unit=iw)
        end if
      end do
      ! Total disturbances files
      iw = 3500+j
      write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,'_total',a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),filename(j),trim(output%Energy),trim(output%info),trim(output%BField),trim(output%SOC),trim(output%EField),trim(output%suffix)
      open (unit=iw, file=varm, status='replace', form='formatted')
      write(unit=iw, fmt="('#     energy    , amplitude of ',a,' , real part of ',a,' , imag part of ',a,' ,  phase of ',a,'  ,  cosine of ',a,'  ,  sine of ',a,'  ')") filename(j),filename(j),filename(j),filename(j),filename(j),filename(j)
      close(unit=iw)
    end do

  end subroutine create_disturbance_files

  subroutine open_disturbance_files()
  !! This subroutine opens all the files needed for the disturbances
    use mod_parameters, only: output, renorm, renormnb, missing_files
    use mod_mpi_pars
    use mod_system, only: s => sys
    implicit none

    character(len=500)  :: varm
    integer :: i,j,iw,err,errt=0

    do j=1,7
      do i=1,s%nAtoms
        iw = 3000+(i-1)*7+j
        write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,'_pos=',i0,a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),filename(j),i,trim(output%Energy),trim(output%info),trim(output%BField),trim(output%SOC),trim(output%EField),trim(output%suffix)
        open (unit=iw, file=varm, status='old', position='append', form='formatted', iostat=err)
        errt = errt + err
        if(err/=0) missing_files = trim(missing_files) // " " // trim(varm)
        if(renorm) then
          iw = iw+1000
          write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/r',a,'_pos=',i0,a,a,a,a,a,'_renormnb=',i0,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),filename(j),i,trim(output%Energy),trim(output%info),trim(output%BField),trim(output%SOC),trim(output%EField),renormnb,trim(output%suffix)
          open (unit=iw, file=varm, status='old', position='append', form='formatted', iostat=err)
          errt = errt + err
          if(err/=0) missing_files = trim(missing_files) // " " // trim(varm)
        end if
      end do
      ! Total disturbances files
      iw = 3500+j
      write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,'_total',a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),filename(j),trim(output%Energy),trim(output%info),trim(output%BField),trim(output%SOC),trim(output%EField),trim(output%suffix)
      open (unit=iw, file=varm, status='old', position='append', form='formatted', iostat=err)
      errt = errt + err
      if(err/=0) missing_files = trim(missing_files) // " " // trim(varm)
    end do
    ! Stop if some file does not exist
    if(errt/=0) call abortProgram("[openclose_disturbance_files] Some file(s) do(es) not exist! Stopping before starting calculations..." // NEW_LINE('A') // trim(missing_files))

  end subroutine open_disturbance_files

  subroutine close_disturbance_files()
  !! This subroutine closes all the files needed for the disturbances
    use mod_parameters, only: renorm
    use mod_system, only: s => sys
    implicit none

    integer :: i,j,iw

    do j=1,7
      do i=1,s%nAtoms
        iw = 3000+(i-1)*7+j
        close(unit=iw)

        if(renorm) then
         iw = iw+1000
         close(unit=iw)
        end if
      end do
      ! Total disturbances files
      iw = 3500+j
      close(unit=iw)

    end do
  end subroutine close_disturbance_files

  ! This subroutine write all the disturbances into files
  ! (already opened with openclose_disturbance_files(1))
  ! Some information may also be written on the screen
  subroutine write_disturbances(e)
    use mod_f90_kind
    use mod_parameters, only: renorm,output,lwriteonscreen
    use mod_magnet, only: mvec_spherical,mtotal_spherical
    use mod_System, only: s => sys
    implicit none
    integer  :: i,iw
    real(double),intent(in) :: e

    call open_disturbance_files()

    if(lwriteonscreen) write(output%unit_loop,"(' ################# Disturbances: #################')")
    ! Writing Spin, Charge and Orbital disturbances
    do i=1,s%nAtoms
      if(lwriteonscreen) then
        write(output%unit_loop,"('|--------------- Energy = ',es11.4,' , Plane: ',i0,' ---------------|')") e,i

        write(output%unit_loop,"('     Cd  = (',es16.9,') + i(',es16.9,')')") real(disturbances(1,i)),aimag(disturbances(1,i))
        write(output%unit_loop,"(' abs(Cd) = ',es16.9)") abs(disturbances(1,i))
        write(output%unit_loop,"('atan(Cd) = ',es16.9)") atan2(aimag(disturbances(1,i)),real(disturbances(1,i)))

        write(output%unit_loop,"('     Sdx  = (',es16.9,') + i(',es16.9,')')") real(disturbances(2,i)),aimag(disturbances(2,i))
        write(output%unit_loop,"(' abs(Sdx) = ',es16.9)") abs(disturbances(2,i))
        write(output%unit_loop,"('atan(Sdx) = ',es16.9)") atan2(aimag(disturbances(2,i)),real(disturbances(2,i)))

        write(output%unit_loop,"('     Sdy  = (',es16.9,') + i(',es16.9,')')") real(disturbances(3,i)),aimag(disturbances(3,i))
        write(output%unit_loop,"(' abs(Sdy) = ',es16.9)") abs(disturbances(3,i))
        write(output%unit_loop,"('atan(Sdy) = ',es16.9)") atan2(aimag(disturbances(3,i)),real(disturbances(3,i)))

        write(output%unit_loop,"('     Sdz  = (',es16.9,') + i(',es16.9,')')") real(disturbances(4,i)),aimag(disturbances(4,i))
        write(output%unit_loop,"(' abs(Sdz) = ',es16.9)") abs(disturbances(4,i))
        write(output%unit_loop,"('atan(Sdz) = ',es16.9)") atan2(aimag(disturbances(4,i)),real(disturbances(4,i)))

        write(output%unit_loop,"('     Ldx  = (',es16.9,') + i(',es16.9,')')") real(disturbances(5,i)),aimag(disturbances(5,i))
        write(output%unit_loop,"(' abs(Ldx) = ',es16.9)") abs(disturbances(5,i))
        write(output%unit_loop,"('atan(Ldx) = ',es16.9)") atan2(aimag(disturbances(5,i)),real(disturbances(5,i)))

        write(output%unit_loop,"('     Ldy  = (',es16.9,') + i(',es16.9,')')") real(disturbances(6,i)),aimag(disturbances(6,i))
        write(output%unit_loop,"(' abs(Ldy) = ',es16.9)") abs(disturbances(6,i))
        write(output%unit_loop,"('atan(Ldy) = ',es16.9)") atan2(aimag(disturbances(6,i)),real(disturbances(6,i)))

        write(output%unit_loop,"('     Ldz  = (',es16.9,') + i(',es16.9,')')") real(disturbances(7,i)),aimag(disturbances(7,i))
        write(output%unit_loop,"(' abs(Ldz) = ',es16.9)") abs(disturbances(7,i))
        write(output%unit_loop,"('atan(Ldz) = ',es16.9)") atan2(aimag(disturbances(7,i)),real(disturbances(7,i)))
      end if

      ! Writing charge disturbance
      iw = 3000+(i-1)*7
      write(unit=iw+1,fmt="(9(es16.9,2x))") e, abs(disturbances(1,i)) , real(disturbances(1,i)) , aimag(disturbances(1,i)) , atan2(aimag(disturbances(1,i)),real(disturbances(1,i))) , real(disturbances(1,i))/abs(disturbances(1,i)) , aimag(disturbances(1,i))/abs(disturbances(1,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing x-component spin disturbance
      write(unit=iw+2,fmt="(9(es16.9,2x))") e, abs(disturbances(2,i)) , real(disturbances(2,i)) , aimag(disturbances(2,i)) , atan2(aimag(disturbances(2,i)),real(disturbances(2,i))) , real(disturbances(2,i))/abs(disturbances(2,i)) , aimag(disturbances(2,i))/abs(disturbances(2,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing y-component spin disturbance
      write(unit=iw+3,fmt="(9(es16.9,2x))") e, abs(disturbances(3,i)) , real(disturbances(3,i)) , aimag(disturbances(3,i)) , atan2(aimag(disturbances(3,i)),real(disturbances(3,i))) , real(disturbances(3,i))/abs(disturbances(3,i)) , aimag(disturbances(3,i))/abs(disturbances(3,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing z-component spin disturbance
      write(unit=iw+4,fmt="(9(es16.9,2x))") e, abs(disturbances(4,i)) , real(disturbances(4,i)) , aimag(disturbances(4,i)) , atan2(aimag(disturbances(4,i)),real(disturbances(4,i))) , real(disturbances(4,i))/abs(disturbances(4,i)) , aimag(disturbances(4,i))/abs(disturbances(4,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)

      ! Writing x-component orbital disturbance
      write(unit=iw+5,fmt="(9(es16.9,2x))") e, abs(disturbances(5,i)) , real(disturbances(5,i)) , aimag(disturbances(5,i)) , atan2(aimag(disturbances(5,i)),real(disturbances(5,i))) , real(disturbances(5,i))/abs(disturbances(5,i)) , aimag(disturbances(5,i))/abs(disturbances(5,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing y-component orbital disturbance
      write(unit=iw+6,fmt="(9(es16.9,2x))") e, abs(disturbances(6,i)) , real(disturbances(6,i)) , aimag(disturbances(6,i)) , atan2(aimag(disturbances(6,i)),real(disturbances(6,i))) , real(disturbances(6,i))/abs(disturbances(6,i)) , aimag(disturbances(6,i))/abs(disturbances(6,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing z-component orbital disturbance
      write(unit=iw+7,fmt="(9(es16.9,2x))") e, abs(disturbances(7,i)) , real(disturbances(7,i)) , aimag(disturbances(7,i)) , atan2(aimag(disturbances(7,i)),real(disturbances(7,i))) , real(disturbances(7,i))/abs(disturbances(7,i)) , aimag(disturbances(7,i))/abs(disturbances(7,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)

      ! Writing renormalized disturbances
      if(renorm) then
        ! Writing renormalized charge disturbance
        write(unit=iw+1001,fmt="(9(es16.9,2x))") e, abs(rdisturbances(1,i)) , real(rdisturbances(1,i)) , aimag(rdisturbances(1,i)) , atan2(aimag(rdisturbances(1,i)),real(rdisturbances(1,i))) , real(rdisturbances(1,i))/abs(rdisturbances(1,i)) , aimag(rdisturbances(1,i))/abs(rdisturbances(1,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized x-component spin disturbance
        write(unit=iw+1002,fmt="(9(es16.9,2x))") e, abs(rdisturbances(2,i)) , real(rdisturbances(2,i)) , aimag(rdisturbances(2,i)) , atan2(aimag(rdisturbances(2,i)),real(rdisturbances(2,i))) , real(rdisturbances(2,i))/abs(rdisturbances(2,i)) , aimag(rdisturbances(2,i))/abs(rdisturbances(2,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized y-component spin disturbance
        write(unit=iw+1003,fmt="(9(es16.9,2x))") e, abs(rdisturbances(3,i)) , real(rdisturbances(3,i)) , aimag(rdisturbances(3,i)) , atan2(aimag(rdisturbances(3,i)),real(rdisturbances(3,i))) , real(rdisturbances(3,i))/abs(rdisturbances(3,i)) , aimag(rdisturbances(3,i))/abs(rdisturbances(3,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized z-component spin disturbance
        write(unit=iw+1004,fmt="(9(es16.9,2x))") e, abs(rdisturbances(4,i)) , real(rdisturbances(4,i)) , aimag(rdisturbances(4,i)) , atan2(aimag(rdisturbances(4,i)),real(rdisturbances(4,i))) , real(rdisturbances(4,i))/abs(rdisturbances(4,i)) , aimag(rdisturbances(4,i))/abs(rdisturbances(4,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)

        ! Writing renormalized x-component orbital disturbance
        write(unit=iw+1005,fmt="(9(es16.9,2x))") e, abs(rdisturbances(5,i)) , real(rdisturbances(5,i)) , aimag(rdisturbances(5,i)) , atan2(aimag(rdisturbances(5,i)),real(rdisturbances(5,i))) , real(rdisturbances(5,i))/abs(rdisturbances(5,i)) , aimag(rdisturbances(5,i))/abs(rdisturbances(5,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized y-component orbital disturbance
        write(unit=iw+1006,fmt="(9(es16.9,2x))") e, abs(rdisturbances(6,i)) , real(rdisturbances(6,i)) , aimag(rdisturbances(6,i)) , atan2(aimag(rdisturbances(6,i)),real(rdisturbances(6,i))) , real(rdisturbances(6,i))/abs(rdisturbances(6,i)) , aimag(rdisturbances(6,i))/abs(rdisturbances(6,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized z-component orbital disturbance
        write(unit=iw+1007,fmt="(9(es16.9,2x))") e, abs(rdisturbances(7,i)) , real(rdisturbances(7,i)) , aimag(rdisturbances(7,i)) , atan2(aimag(rdisturbances(7,i)),real(rdisturbances(7,i))) , real(rdisturbances(7,i))/abs(rdisturbances(7,i)) , aimag(rdisturbances(7,i))/abs(rdisturbances(7,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      end if
    end do

    ! Writing total charge disturbance
    iw = 3500
    write(unit=iw+1,fmt="(9(es16.9,2x))") e, abs(total_disturbances(1)) , real(total_disturbances(1)) , aimag(total_disturbances(1)) , atan2(aimag(total_disturbances(1)),real(total_disturbances(1))) , real(total_disturbances(1))/abs(total_disturbances(1)) , aimag(total_disturbances(1))/abs(total_disturbances(1)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing x-component total spin disturbance
    write(unit=iw+2,fmt="(9(es16.9,2x))") e, abs(total_disturbances(2)) , real(total_disturbances(2)) , aimag(total_disturbances(2)) , atan2(aimag(total_disturbances(2)),real(total_disturbances(2))) , real(total_disturbances(2))/abs(total_disturbances(2)) , aimag(total_disturbances(2))/abs(total_disturbances(2)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing y-component total spin disturbance
    write(unit=iw+3,fmt="(9(es16.9,2x))") e, abs(total_disturbances(3)) , real(total_disturbances(3)) , aimag(total_disturbances(3)) , atan2(aimag(total_disturbances(3)),real(total_disturbances(3))) , real(total_disturbances(3))/abs(total_disturbances(3)) , aimag(total_disturbances(3))/abs(total_disturbances(3)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing z-component total spin disturbance
    write(unit=iw+4,fmt="(9(es16.9,2x))") e, abs(total_disturbances(4)) , real(total_disturbances(4)) , aimag(total_disturbances(4)) , atan2(aimag(total_disturbances(4)),real(total_disturbances(4))) , real(total_disturbances(4))/abs(total_disturbances(4)) , aimag(total_disturbances(4))/abs(total_disturbances(4)) , mtotal_spherical(2) , mtotal_spherical(3)

    ! Writing x-component total orbital disturbance
    write(unit=iw+5,fmt="(9(es16.9,2x))") e, abs(total_disturbances(5)) , real(total_disturbances(5)) , aimag(total_disturbances(5)) , atan2(aimag(total_disturbances(5)),real(total_disturbances(5))) , real(total_disturbances(5))/abs(total_disturbances(5)) , aimag(total_disturbances(5))/abs(total_disturbances(5)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing y-component total orbital disturbance
    write(unit=iw+6,fmt="(9(es16.9,2x))") e, abs(total_disturbances(6)) , real(total_disturbances(6)) , aimag(total_disturbances(6)) , atan2(aimag(total_disturbances(6)),real(total_disturbances(6))) , real(total_disturbances(6))/abs(total_disturbances(6)) , aimag(total_disturbances(6))/abs(total_disturbances(6)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing z-component total orbital disturbance
    write(unit=iw+7,fmt="(9(es16.9,2x))") e, abs(total_disturbances(7)) , real(total_disturbances(7)) , aimag(total_disturbances(7)) , atan2(aimag(total_disturbances(7)),real(total_disturbances(7))) , real(total_disturbances(7))/abs(total_disturbances(7)) , aimag(total_disturbances(7))/abs(total_disturbances(7)) , mtotal_spherical(2) , mtotal_spherical(3)


    call close_disturbance_files()
  end subroutine write_disturbances

  subroutine create_dc_disturbance_files
  !! This subroutine creates all the files needed for the dc-limit disturbances
    use mod_parameters, only: count, output, renorm, renormnb
    use mod_magnet, only: dcprefix, dcfield_dependence, dcfield, dc_header
    use mod_mpi_pars
    use mod_system, only: s => sys
    implicit none

    character(len=500)  :: varm
    integer :: i,j,iw

    do i=1,s%nAtoms
      do j=1,7
        iw = 30000+(i-1)*7+j
        write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,a,'_',a,'_pos=',i0,a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),trim(dcprefix(count)),filename(j),trim(dcfield(dcfield_dependence)),i,trim(output%Energy),trim(output%info),trim(output%dcBField),trim(output%SOC),trim(output%EField),trim(output%suffix)
        open (unit=iw, file=varm, status='replace', form='formatted')
        write(unit=iw, fmt="('#',a,' imag part of ',a,' , real part of ',a,' ,  phase of ',a,'  ,  cosine of ',a,'  ,  sine of ',a,'  , mag angle theta , mag angle phi  ')") trim(dc_header),filename(j),filename(j),filename(j),filename(j),filename(j)
        close(unit=iw)
        if(renorm) then
          iw = iw+1000
          write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,'r',a,'_',a,'_pos=',i0,a,a,a,a,a,'_renormnb=',i0,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),trim(dcprefix(count)),filename(j),trim(dcfield(dcfield_dependence)),i,trim(output%Energy),trim(output%info),trim(output%dcBField),trim(output%SOC),trim(output%EField),renormnb,trim(output%suffix)
          open (unit=iw, file=varm, status='replace', form='formatted')
          write(unit=iw, fmt="('#',a,' imag part of ',a,' , real part of ',a,' ,  phase of ',a,'  ,  cosine of ',a,'  ,  sine of ',a,'  , mag angle theta , mag angle phi  ')") trim(dc_header),filename(j),filename(j),filename(j),filename(j),filename(j)
          close(unit=iw)
        end if
      end do
      ! Total disturbances files
      iw = 35000+j
      write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,a,'_',a,'_total',a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),trim(dcprefix(count)),filename(j),trim(dcfield(dcfield_dependence)),trim(output%Energy),trim(output%info),trim(output%dcBField),trim(output%SOC),trim(output%EField),trim(output%suffix)
      open (unit=iw, file=varm, status='replace', form='formatted')
      write(unit=iw, fmt="('#',a,' imag part of ',a,' , real part of ',a,' ,  phase of ',a,'  ,  cosine of ',a,'  ,  sine of ',a,'  , mag angle theta , mag angle phi  ')") trim(dc_header),filename(j),filename(j),filename(j),filename(j),filename(j)
      close(unit=iw)
    end do
  end subroutine create_dc_disturbance_files

  subroutine open_dc_disturbance_files
  ! This subroutine opens all the files needed for the dc-limit disturbances
   use mod_parameters, only: output, count, renorm, renormnb, missing_files
   use mod_magnet,     only: dcprefix, dcfield_dependence, dcfield
   use mod_mpi_pars, only: abortProgram
   use mod_system,     only: s => sys
   implicit none

   character(len=500)  :: varm
   integer :: i,j,iw,err,errt=0

   do j=1,7
    do i=1,s%nAtoms
      iw = 30000+(i-1)*7+j
      write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,a,'_',a,'_pos=',i0,a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),trim(dcprefix(count)),filename(j),trim(dcfield(dcfield_dependence)),i,trim(output%Energy),trim(output%info),trim(output%dcBField),trim(output%SOC),trim(output%EField),trim(output%suffix)
      open (unit=iw, file=varm, status='old', position='append', form='formatted', iostat=err)
      errt = errt + err
      if(err/=0) missing_files = trim(missing_files) // " " // trim(varm)
      if(renorm) then
        iw = iw+1000
        write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,'r',a,'_',a,'_pos=',i0,a,a,a,a,a,'_renormnb=',i0,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),trim(dcprefix(count)),filename(j),trim(dcfield(dcfield_dependence)),i,trim(output%Energy),trim(output%info),trim(output%dcBField),trim(output%SOC),trim(output%EField),renormnb,trim(output%suffix)
        open (unit=iw, file=varm, status='old', position='append', form='formatted', iostat=err)
        errt = errt + err
        if(err/=0) missing_files = trim(missing_files) // " " // trim(varm)
      end if
    end do
     ! Total disturbances files
     iw = 35000+j
     write(varm,"('./results/',a1,'SOC/',a,'/',a,a,'/',a,a,'_',a,'_total',a,a,a,a,a,a,'.dat')") output%SOCchar,trim(output%Sites),trim(folder(j)),trim(output%hfr),trim(dcprefix(count)),filename(j),trim(dcfield(dcfield_dependence)),trim(output%Energy),trim(output%info),trim(output%dcBField),trim(output%SOC),trim(output%EField),trim(output%suffix)
     open (unit=iw, file=varm, status='old', position='append', form='formatted', iostat=err)
     errt = errt + err
     if(err/=0) missing_files = trim(missing_files) // " " // trim(varm)
   end do

   ! Stop if some file does not exist
   if(errt/=0) call abortProgram("[openclose_dc_disturbance_files] Some file(s) do(es) not exist! Stopping before starting calculations..." // NEW_LINE('A') // trim(missing_files))
  end subroutine open_dc_disturbance_files

  subroutine close_dc_disturbance_files()
  !! This subroutine closes all the files needed for the dc-limit disturbances
    use mod_parameters, only: renorm
    use mod_system, only: s => sys
    implicit none

    integer :: i,j,iw

    do j=1,7
      do i=1,s%nAtoms
        iw = 30000+(i-1)*7+j
        close(unit=iw)

        if(renorm) then
          iw = iw+1000
          close(unit=iw)
        end if
      end do
      ! Total disturbances files
      iw = 35000+j
      close(unit=iw)
    end do
  end subroutine close_dc_disturbance_files

  subroutine write_dc_disturbances()
    !! This subroutine write all the dc-limit disturbances into files
    !! (already opened with openclose_dc_disturbance_files(1))
    !! Some information may also be written on the screen
    use mod_f90_kind
    use mod_parameters, only: renorm,output,lwriteonscreen
    use mod_magnet, only: mvec_spherical, mtotal_spherical, dcfield, dcfield_dependence, dc_fields, hw_count
    use mod_System, only: s => sys
    implicit none
    integer  :: i,iw

    call open_dc_disturbance_files()

    if(lwriteonscreen) write(output%unit_loop,"(' ################# Disturbances: #################')")
    ! Writing Spin, Charge and Orbital disturbances
    do i=1, s%nAtoms
      if(lwriteonscreen) then
        write(output%unit_loop,"('|--------------- ',a,' = ',a,' , Plane: ',i0,' ---------------|')") trim(dcfield(dcfield_dependence)),trim(dc_fields(hw_count)),i

        write(output%unit_loop,"('     Cd  = (',es16.9,') + i(',es16.9,')')") real(disturbances(1,i)),aimag(disturbances(1,i))
        write(output%unit_loop,"(' abs(Cd) = ',es16.9)") abs(disturbances(1,i))
        write(output%unit_loop,"('atan(Cd) = ',es16.9)") atan2(aimag(disturbances(1,i)),real(disturbances(1,i)))

        write(output%unit_loop,"('     Sdx  = (',es16.9,') + i(',es16.9,')')") real(disturbances(2,i)),aimag(disturbances(2,i))
        write(output%unit_loop,"(' abs(Sdx) = ',es16.9)") abs(disturbances(2,i))
        write(output%unit_loop,"('atan(Sdx) = ',es16.9)") atan2(aimag(disturbances(2,i)),real(disturbances(2,i)))

        write(output%unit_loop,"('     Sdy  = (',es16.9,') + i(',es16.9,')')") real(disturbances(3,i)),aimag(disturbances(3,i))
        write(output%unit_loop,"(' abs(Sdy) = ',es16.9)") abs(disturbances(3,i))
        write(output%unit_loop,"('atan(Sdy) = ',es16.9)") atan2(aimag(disturbances(3,i)),real(disturbances(3,i)))

        write(output%unit_loop,"('     Sdz  = (',es16.9,') + i(',es16.9,')')") real(disturbances(4,i)),aimag(disturbances(4,i))
        write(output%unit_loop,"(' abs(Sdz) = ',es16.9)") abs(disturbances(4,i))
        write(output%unit_loop,"('atan(Sdz) = ',es16.9)") atan2(aimag(disturbances(4,i)),real(disturbances(4,i)))

        write(output%unit_loop,"('     Ldx  = (',es16.9,') + i(',es16.9,')')") real(disturbances(5,i)),aimag(disturbances(5,i))
        write(output%unit_loop,"(' abs(Ldx) = ',es16.9)") abs(disturbances(5,i))
        write(output%unit_loop,"('atan(Ldx) = ',es16.9)") atan2(aimag(disturbances(5,i)),real(disturbances(5,i)))

        write(output%unit_loop,"('     Ldy  = (',es16.9,') + i(',es16.9,')')") real(disturbances(6,i)),aimag(disturbances(6,i))
        write(output%unit_loop,"(' abs(Ldy) = ',es16.9)") abs(disturbances(6,i))
        write(output%unit_loop,"('atan(Ldy) = ',es16.9)") atan2(aimag(disturbances(6,i)),real(disturbances(6,i)))

        write(output%unit_loop,"('     Ldz  = (',es16.9,') + i(',es16.9,')')") real(disturbances(7,i)),aimag(disturbances(7,i))
        write(output%unit_loop,"(' abs(Ldz) = ',es16.9)") abs(disturbances(7,i))
        write(output%unit_loop,"('atan(Ldz) = ',es16.9)") atan2(aimag(disturbances(7,i)),real(disturbances(7,i)))
      end if

      ! Writing charge disturbance
      iw = 30000+(i-1)*7
      write(unit=iw+1,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(1,i)) , real(disturbances(1,i)) , atan2(aimag(disturbances(1,i)),real(disturbances(1,i))) , real(disturbances(1,i))/abs(disturbances(1,i)) , aimag(disturbances(1,i))/abs(disturbances(1,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing x-component spin disturbance
      write(unit=iw+2,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(2,i)) , real(disturbances(2,i)) , atan2(aimag(disturbances(2,i)),real(disturbances(2,i))) , real(disturbances(2,i))/abs(disturbances(2,i)) , aimag(disturbances(2,i))/abs(disturbances(2,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing y-component spin disturbance
      write(unit=iw+3,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(3,i)) , real(disturbances(3,i)) , atan2(aimag(disturbances(3,i)),real(disturbances(3,i))) , real(disturbances(3,i))/abs(disturbances(3,i)) , aimag(disturbances(3,i))/abs(disturbances(3,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing z-component spin disturbance
      write(unit=iw+4,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(4,i)) , real(disturbances(4,i)) , atan2(aimag(disturbances(4,i)),real(disturbances(4,i))) , real(disturbances(4,i))/abs(disturbances(4,i)) , aimag(disturbances(4,i))/abs(disturbances(4,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)

      ! Writing x-component orbital disturbance
      write(unit=iw+5,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(5,i)) , real(disturbances(5,i)) , atan2(aimag(disturbances(5,i)),real(disturbances(5,i))) , real(disturbances(5,i))/abs(disturbances(5,i)) , aimag(disturbances(5,i))/abs(disturbances(5,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing y-component orbital disturbance
      write(unit=iw+6,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(6,i)) , real(disturbances(6,i)) , atan2(aimag(disturbances(6,i)),real(disturbances(6,i))) , real(disturbances(6,i))/abs(disturbances(6,i)) , aimag(disturbances(6,i))/abs(disturbances(6,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      ! Writing z-component orbital disturbance
      write(unit=iw+7,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(disturbances(7,i)) , real(disturbances(7,i)) , atan2(aimag(disturbances(7,i)),real(disturbances(7,i))) , real(disturbances(7,i))/abs(disturbances(7,i)) , aimag(disturbances(7,i))/abs(disturbances(7,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)

      ! Writing renormalized disturbances
      if(renorm) then
        ! Writing renormalized charge disturbance
        write(unit=iw+1001,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(1,i)) , real(rdisturbances(1,i)) , atan2(aimag(rdisturbances(1,i)),real(rdisturbances(1,i))) , real(rdisturbances(1,i))/abs(rdisturbances(1,i)) , aimag(rdisturbances(1,i))/abs(rdisturbances(1,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized x-component spin disturbance
        write(unit=iw+1002,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(2,i)) , real(rdisturbances(2,i)) , atan2(aimag(rdisturbances(2,i)),real(rdisturbances(2,i))) , real(rdisturbances(2,i))/abs(rdisturbances(2,i)) , aimag(rdisturbances(2,i))/abs(rdisturbances(2,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized y-component spin disturbance
        write(unit=iw+1003,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(3,i)) , real(rdisturbances(3,i)) , atan2(aimag(rdisturbances(3,i)),real(rdisturbances(3,i))) , real(rdisturbances(3,i))/abs(rdisturbances(3,i)) , aimag(rdisturbances(3,i))/abs(rdisturbances(3,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized z-component spin disturbance
        write(unit=iw+1004,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(4,i)) , real(rdisturbances(4,i)) , atan2(aimag(rdisturbances(4,i)),real(rdisturbances(4,i))) , real(rdisturbances(4,i))/abs(rdisturbances(4,i)) , aimag(rdisturbances(4,i))/abs(rdisturbances(4,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)

        ! Writing renormalized x-component orbital disturbance
        write(unit=iw+1005,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(5,i)) , real(rdisturbances(5,i)) , atan2(aimag(rdisturbances(5,i)),real(rdisturbances(5,i))) , real(rdisturbances(5,i))/abs(rdisturbances(5,i)) , aimag(rdisturbances(5,i))/abs(rdisturbances(5,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized y-component orbital disturbance
        write(unit=iw+1006,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(6,i)) , real(rdisturbances(6,i)) , atan2(aimag(rdisturbances(6,i)),real(rdisturbances(6,i))) , real(rdisturbances(6,i))/abs(rdisturbances(6,i)) , aimag(rdisturbances(6,i))/abs(rdisturbances(6,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
        ! Writing renormalized z-component orbital disturbance
        write(unit=iw+1007,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(rdisturbances(7,i)) , real(rdisturbances(7,i)) , atan2(aimag(rdisturbances(7,i)),real(rdisturbances(7,i))) , real(rdisturbances(7,i))/abs(rdisturbances(7,i)) , aimag(rdisturbances(7,i))/abs(rdisturbances(7,i)) , mvec_spherical(2,i) , mvec_spherical(3,i)
      end if
    end do

    ! Writing total charge disturbance
    iw = 35000
    write(unit=iw+1,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(1)) , real(total_disturbances(1)) , atan2(aimag(total_disturbances(1)),real(total_disturbances(1))) , real(total_disturbances(1))/abs(total_disturbances(1)) , aimag(total_disturbances(1))/abs(total_disturbances(1)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing x-component total spin disturbance
    write(unit=iw+2,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(2)) , real(total_disturbances(2)) , atan2(aimag(total_disturbances(2)),real(total_disturbances(2))) , real(total_disturbances(2))/abs(total_disturbances(2)) , aimag(total_disturbances(2))/abs(total_disturbances(2)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing y-component total spin disturbance
    write(unit=iw+3,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(3)) , real(total_disturbances(3)) , atan2(aimag(total_disturbances(3)),real(total_disturbances(3))) , real(total_disturbances(3))/abs(total_disturbances(3)) , aimag(total_disturbances(3))/abs(total_disturbances(3)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing z-component total spin disturbance
    write(unit=iw+4,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(4)) , real(total_disturbances(4)) , atan2(aimag(total_disturbances(4)),real(total_disturbances(4))) , real(total_disturbances(4))/abs(total_disturbances(4)) , aimag(total_disturbances(4))/abs(total_disturbances(4)) , mtotal_spherical(2) , mtotal_spherical(3)

    ! Writing x-component total orbital disturbance
    write(unit=iw+5,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(5)) , real(total_disturbances(5)) , atan2(aimag(total_disturbances(5)),real(total_disturbances(5))) , real(total_disturbances(5))/abs(total_disturbances(5)) , aimag(total_disturbances(5))/abs(total_disturbances(5)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing y-component total orbital disturbance
    write(unit=iw+6,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(6)) , real(total_disturbances(6)) , atan2(aimag(total_disturbances(6)),real(total_disturbances(6))) , real(total_disturbances(6))/abs(total_disturbances(6)) , aimag(total_disturbances(6))/abs(total_disturbances(6)) , mtotal_spherical(2) , mtotal_spherical(3)
    ! Writing z-component total orbital disturbance
    write(unit=iw+7,fmt="(a,2x,7(es16.9,2x))") trim(dc_fields(hw_count)) , aimag(total_disturbances(7)) , real(total_disturbances(7)) , atan2(aimag(total_disturbances(7)),real(total_disturbances(7))) , real(total_disturbances(7))/abs(total_disturbances(7)) , aimag(total_disturbances(7))/abs(total_disturbances(7)) , mtotal_spherical(2) , mtotal_spherical(3)

    call close_dc_disturbance_files()

  end subroutine write_dc_disturbances

  ! This subroutine sorts disturbance files
  subroutine sort_disturbances()
    use mod_f90_kind
    use mod_parameters, only: renorm,itype
    use mod_tools, only: sort_file
    use mod_System, only: s => sys
    implicit none
    integer :: i,j,iw,idc=1

    ! Opening disturbance files
    if(itype==9) then
     idc=10
     call open_dc_disturbance_files()
    else
     call open_disturbance_files()
    end if

    ! Sorting total disturbance
    iw = 3500*idc
    do j=1,7
     call sort_file(iw+j)
    end do


    do i=1, s%nAtoms
     ! Sorting disturbance files
     iw = 3000*idc+(i-1)*7
     do j=1,7
       call sort_file(iw+j)
     end do

     ! Sorting renormalized disturbances
     if(renorm) then
       do j=1001,1007
        call sort_file(iw+j)
       end do
     end if
    end do

    ! Closing disturbance files
    if(itype==9) then
     call close_dc_disturbance_files()
    else
     call close_disturbance_files()
    end if

  end subroutine sort_disturbances

end module mod_disturbances
