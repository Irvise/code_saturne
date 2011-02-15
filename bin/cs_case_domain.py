#!/usr/bin/env python
#-------------------------------------------------------------------------------
#   This file is part of the Code_Saturne Solver.
#
#   Copyright (C) 2009-2011  EDF
#
#   Code_Saturne is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the
#   Free Software Foundation; either version 2 of the License,
#   or (at your option) any later version.
#
#   Code_Saturne is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty
#   of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public Licence
#   along with the Code_Saturne Preprocessor; if not, write to the
#   Free Software Foundation, Inc.,
#   51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#-------------------------------------------------------------------------------

import ConfigParser
import datetime
import fnmatch
import os
import os.path
import sys
import shutil
import stat

import cs_config
import cs_compile

from cs_exec_environment import run_command


#===============================================================================
# Constants
#===============================================================================

solver_base_name = 'cs_solver'

#===============================================================================
# Utility functions
#===============================================================================

def any_to_str(arg):
    """Transform single values or lists to a whitespace-separated string"""

    s = ''

    if type(arg) == tuple or type(arg) == list:
        for e in arg:
            s += ' ' + str(e)
        return s[1:]

    else:
        return str(arg)

#-------------------------------------------------------------------------------

class RunCaseError(Exception):
    """Base class for exception handling."""

    def __init__(self, *args):
        self.args = args

    def __str__(self):
        if len(self.args) == 1:
            return str(self.args[0])
        else:
            return str(self.args)

#   def __repr__(self):
#       return "%s(*%s)" % (self.__class__.__name__, repr(self.args))

#===============================================================================
# Classes
#===============================================================================

class base_domain:
    """
    Base class from which classes handling running case should inherit.
    """

    #---------------------------------------------------------------------------

    def __init__(self,
                 package,
                 name = None,             # domain name
                 n_procs = None,          # recommended number of processes
                 n_procs_min = 1,         # min. number of processes
                 n_procs_max = None):     # max. number of processes

        # Package specific information

        self.package = package

        # Names, directories, and files in case structure

        self.case_dir = None

        self.name = name # used for multiple domains only

        self.data_dir = None
        self.result_dir = None
        self.src_dir = None

        self.mesh_dir = None

        # Working directory and executable

        self.exec_dir = None
        self.solver_path = None

        # Execution and debugging options

        self.n_procs = n_procs
        self.n_procs_min = max(1, n_procs_min)
        self.n_procs_max = n_procs_max

        if self.n_procs == None:
            self.n_procs = 1
        self.n_procs = max(self.n_procs, self.n_procs_min)
        if self.n_procs_max != None:
            self.n_procs = min(self.n_procs, self.n_procs_max)

        self.valgrind = None

        # Error reporting
        self.error = ''

    #---------------------------------------------------------------------------

    def set_case_dir(self, case_dir):

        # Names, directories, and files in case structure

        self.case_dir = case_dir

        if self.name != None:
            self.case_dir = os.path.join(self.case_dir, self.name)

        self.data_dir = os.path.join(self.case_dir, 'DATA')
        self.result_dir = os.path.join(self.case_dir, 'RESU')
        self.src_dir = os.path.join(self.case_dir, 'SRC')

    #---------------------------------------------------------------------------

    def set_exec_dir(self, exec_dir):

        if os.path.isabs(exec_dir):
            self.exec_dir = exec_dir
        else:
            self.exec_dir = os.path.join(self.case_dir, 'RESU', exec_dir)

        if self.name != None:
            self.exec_dir = os.path.join(self.exec_dir, self.name)

        if not os.path.isdir(self.exec_dir):
            os.makedirs(self.exec_dir)

    #---------------------------------------------------------------------------

    def set_result_dir(self, name, given_dir = None):
        """
        If suffix = true, add suffix to all names in result dir.
        Otherwise, create subdirectory
        """

        if given_dir == None:
            self.result_dir = os.path.join(self.case_dir, 'RESU', name)
        else:
            self.result_dir = given_dir

        if self.name != None:
            self.result_dir = os.path.join(self.result_dir, self.name)

        if not os.path.isdir(self.result_dir):
            os.makedirs(self.result_dir)

    #---------------------------------------------------------------------------

    def copy_data_file(self, name, copy_name=None, description=None):
        """
        Copy a data file to the execution directory.
        """
        if os.path.isabs(name):
            source = name
            if copy_name == None:
                dest = os.path.join(self.exec_dir, os.path.basename(name))
            elif os.path.isabs(copy_name):
                dest = copy_name
            else:
                dest = os.path.join(self.exec_dir, copy_name)
        else:
            source = os.path.join(self.data_dir, name)
            if copy_name == None:
                dest = os.path.join(self.exec_dir, name)
            elif os.path.isabs(copy_name):
                dest = copy_name
            else:
                dest = os.path.join(self.exec_dir, copy_name)

        if os.path.isfile(source):
            shutil.copy2(source, dest)
        else:
            if description != None:
                err_str = \
                    'The ' + description + ' file: ', name, '\n' \
                    'can not be accessed.'
            else:
                err_str = \
                    'File: ', name, '\n' \
                    'can not be accessed.'
            raise RunCaseError(err_str)

    #---------------------------------------------------------------------------

    def copy_result(self, name, purge=False):
        """
        Copy a file or directory to the results directory,
        optionally removing it from the source.
        """

        # Determine absolute source and destination names

        if os.path.isabs(name):
            src = name
            dest = os.path.join(self.result_dir, os.path.basename(name))
        else:
            src = os.path.join(self.exec_dir, name)
            dest = os.path.join(self.result_dir, name)

        # If source and destination are identical, return

        if src == dest:
            return

        # Copy single file

        if os.path.isfile(src):
            shutil.copy2(src, dest)
            if purge:
                os.remove(src)

        # Copy single directory (possibly recursive)
        # Unkike os.path.copytree, the destination directory
        # may already exist.

        elif os.path.isdir(src):

            if not os.path.isdir(dest):
                os.mkdir(dest)
            list = os.listdir(src)
            for f in list:
                f_src = os.path.join(src, f)
                f_dest = os.path.join(dest, f)
                if os.path.isfile(f_src):
                    shutil.copy2(f_src, f_dest)
                elif os.path.isdir(f_src):
                    self.copy_result(f_src, f_dest)

            if purge:
                shutil.rmtree(src)

    #---------------------------------------------------------------------------

    def purge_result(self, name):
        """
        Remove a file or directory from execution directory.
        """

        # Determine absolute name

        if os.path.isabs(name):
            f = name
        else:
            f = os.path.join(self.exec_dir, name)

        # Remove file or directory

        if os.path.isfile(f) or os.path.islink(f):
            os.remove(f)

        elif os.path.isdir(f):
            shutil.rmtree(f)

    #---------------------------------------------------------------------------

    def get_n_procs(self):
        """
        Returns an array (list) containing the current number of processes
        associated with a solver stage followed by the minimum and maximum
        number of processes.
        """

        return [self.n_procs, self.n_procs_min, self.n_procs_max]

    #---------------------------------------------------------------------------

    def set_n_procs(self, n_procs):
        """
        Assign a number of processes to a solver stage.
        """

        self.n_procs = n_procs

    #---------------------------------------------------------------------------

    def solver_args(self, **kw):
        """
        Returns a tuple indicating the solver's working directory,
        executable path, and associated command-line arguments.
        """

        return self.exec_dir, self.solver_path, ''

#-------------------------------------------------------------------------------

class domain(base_domain):
    """Handle running case."""

    #---------------------------------------------------------------------------

    def __init__(self,
                 package,
                 name = None,                 # domain name
                 n_procs = None,              # recommended number of processes
                 n_procs_min = None,          # min. number of processes
                 n_procs_max = None,          # max. number of processes
                 n_procs_partition = None,    # n. processes for partitioner
                 meshes = None,               # name or names of mesh files
                 mesh_dir = None,             # mesh database directory
                 reorient = False,            # reorient badly-oriented meshes
                 partition_list = None,       # list of partitions
                 partition_opts = None,       # partitioner options
                 mode_args = None,            # --quality or --benchmark ?
                 logging_args = None,         # command-line options for logging
                 param = None,                # XML parameters file
                 thermochemistry_data = None, # file name
                 meteo_data = None,           # meteo. profileFile name
                 user_input_files = None,     # file name or names
                 user_scratch_files = None,   # file or directory name or names
                 lib_add = None,              # linker command-line options
                 adaptation = None):          # HOMARD adaptation script

        base_domain.__init__(self, package,
                             name,
                             n_procs,
                             n_procs_min,
                             n_procs_max)

        # Directories, and files in case structure

        self.restart_input_dir = None
        self.mesh_input = None
        self.partition_input = None

        # Default executable

        self.solver_path = self.package.get_solver()

        # Preprocessor options

        if mesh_dir is not None:
            self.mesh_dir = os.path.expanduser(mesh_dir)

        if type(meshes) == list:
            self.meshes = meshes
        else:
            self.meshes = [meshes,]
        self.reorient = reorient

        # Partition options

        self.partition_n_procs = n_procs_partition
        self.partition_list = partition_list
        self.partition_opts = partition_opts

        # Solver options

        self.mode_args = mode_args

        self.logging_args = logging_args

        self.param = param

        # Additional data

        self.thermochemistry_data = thermochemistry_data
        self.meteo_data = meteo_data

        self.user_input_files = user_input_files
        self.user_scratch_files = user_scratch_files

        self.lib_add = lib_add

        # Adaptation using HOMARD
        self.adaptation = adaptation

        # Steps to execute
        self.exec_preprocess = True
        self.exec_partition = True
        self.exec_solver = True

    #---------------------------------------------------------------------------

    def for_domain_str(self):

        if self.name == None:
            return ''
        else:
            return 'for domain ' + str(self.name)

    #---------------------------------------------------------------------------

    def set_case_dir(self, case_dir):

        # Names, directories, and files in case structure

        base_domain.set_case_dir(self, case_dir)

        self.restart_input_dir = os.path.join(self.data_dir, 'restart')
        self.mesh_input = os.path.join(self.data_dir, 'mesh_input')
        self.partition_input = os.path.join(self.data_dir, 'partition')

    #---------------------------------------------------------------------------

    def symlink(self, target, link=None, check_type=None):
        """
        Create a symbolic link to a file, or copy it if links are
        not possible
        """

        if target == None and link == None:
            return
        elif target == None:
            err_str = 'No target for link: ' + link
            raise RunCaseError(err_str)
        elif link == None:
            if self.exec_dir != None:
                link = os.path.join(self.exec_dir,
                                    os.path.basename(target))
            else:
                err_str = 'No path name given for link to: ' + target
                raise RunCaseError(err_str)

        if not os.path.exists(target):
            err_str = 'File: ' + target + ' does not exist.'
            raise RunCaseError(err_str)

        elif check_type == 'file':
            if not os.path.isfile(target):
                err_str = target + ' is not a regular file.'
                raise RunCaseError(err_str)

        elif check_type == 'dir':
            if not os.path.isdir(target):
                err_str = target + ' is not a directory.'
                raise RunCaseError(err_str)

        try:
            os.symlink(target, link)
        except AttributeError:
            shutil.copy2(target, link)

    #---------------------------------------------------------------------------

    def needs_compile(self):
        """
        Compile and link user subroutines if necessary
        """
        # Check if there are files to compile in source path

        dir_files = os.listdir(self.src_dir)

        src_files = (fnmatch.filter(dir_files, '*.c')
                     + fnmatch.filter(dir_files, '*.cxx')
                     + fnmatch.filter(dir_files, '*.cpp')
                     + fnmatch.filter(dir_files, '*.[fF]90'))

        if len(src_files) > 0:
            return True
        else:
            return False

    #---------------------------------------------------------------------------

    def compile_and_link(self):
        """
        Compile and link user subroutines if necessary
        """
        # Check if there are files to compile in source path

        dir_files = os.listdir(self.src_dir)

        src_files = (fnmatch.filter(dir_files, '*.c')
                     + fnmatch.filter(dir_files, '*.cxx')
                     + fnmatch.filter(dir_files, '*.cpp')
                     + fnmatch.filter(dir_files, '*.[fF]90'))

        if len(src_files) > 0:

            # Add header files to list so as not to forget to copy them

            src_files = src_files + (  fnmatch.filter(dir_files, '*.h')
                                     + fnmatch.filter(dir_files, '*.hxx')
                                     + fnmatch.filter(dir_files, '*.hpp'))

            exec_src = os.path.join(self.exec_dir, self.package.srcdir)

            # Copy source files to execution directory

            os.mkdir(exec_src)
            for f in src_files:
                src_file = os.path.join(self.src_dir, f)
                dest_file = os.path.join(exec_src, f)
                shutil.copy2(src_file, dest_file)

            log_name = os.path.join(self.exec_dir, 'compile.log')
            log = open(log_name, 'w')

            retval = cs_compile.compile_and_link(self.package,
                                                 exec_src,
                                                 self.exec_dir,
                                                 self.lib_add,
                                                 keep_going=True,
                                                 stdout=log,
                                                 stderr=log)

            log.close()

            if retval == 0:
                self.solver_path = os.path.join(self.exec_dir,
                                                self.package.solver)
            else:
                # In case of error, copy source to results directory now,
                # as no calculation is possible, then rais exception
                for f in [self.package.srcdir, 'compile.log']:
                    self.copy_result(f)
                raise RunCaseError('Compile or link error.')

    #---------------------------------------------------------------------------

    def check_model_consistency(self):
        """
        Check model user subroutine and xml options consistency
        """
        from cs_check_consistency import check_consistency
        return check_consistency(self.param, self.src_dir, self.n_procs)

    #---------------------------------------------------------------------------

    def copy_preprocessor_data(self):
        """
        Copy preprocessor data to execution directory
        """

        if self.exec_preprocess == False:
            return

        # Study directory
        study_dir = os.path.split(self.case_dir)[0]

        # User config file
        u_cfg = ConfigParser.ConfigParser()
        u_cfg.read(os.path.expanduser('~/.' + self.package.configfile))

        # Global config file
        g_cfg = ConfigParser.ConfigParser()
        g_cfg.read(self.package.get_configfile())

        # A mesh can be found in different mesh database directories
        # (case, study, user, global -- in this order)
        mesh_dirs = []
        if self.mesh_dir is not None:
            mesh_dirs.append(self.mesh_dir)
        if os.path.isdir(os.path.join(study_dir, 'MESH')):
            mesh_dirs.append(os.path.join(study_dir, 'MESH'))
        if u_cfg.has_option('run', 'meshdir'):
            mesh_dirs.append(u_cfg.get('run', 'meshdir'))
        if g_cfg.has_option('run', 'meshdir'):
            mesh_dirs.append(g_cfg.get('run', 'meshdir'))

        # Symlink the different meshes
        for mesh in self.meshes:

            if mesh is None:
                err_str = 'Preprocessing stage required but no mesh is given'
                raise RunCaseError(err_str)

            if (type(mesh) == tuple):
                mesh = mesh[0]

            mesh = os.path.expanduser(mesh)

            if os.path.isabs(mesh):
                mesh_path = mesh
            elif len(mesh_dirs) > 0:
                for mesh_dir in mesh_dirs:
                    mesh_path = os.path.join(mesh_dir, mesh)
                    if os.path.isfile(mesh_path):
                        break
            else:
                err_str = 'No mesh directory given'
                raise RunCaseError(err_str)

            if not os.path.isfile(mesh_path):
                err_str = 'Mesh file ' + mesh + ' not found'
                raise RunCaseError(err_str)

            base_name = os.path.basename(mesh_path)

            link_path = os.path.join(self.exec_dir, base_name)
            self.symlink(mesh_path, link_path)

            # Special case for meshes in EnSight format: link to .geo file
            # necessary (retrieve name through .case file)
            base, ext = os.path.splitext(base_name)
            if ext == '.case':
                try:
                    f = open(mesh_path)
                    text = f.read(4096) # Should be largely sufficient
                    f.close()
                    m = re.search('^model:.*$', text, re.MULTILINE)
                    geo_name = (m.group()).split()[1]
                    mesh_path = os.path.join(self.mesh_dir, geo_name)
                    link_path = os.path.join(self.exec_dir, geo_name)
                    self.symlink(mesh_path, link_path)
                except Exception:
                    err_str = 'Model file name not found in ' + mesh_path
                    raise RunCaseError(err_str)

    #---------------------------------------------------------------------------

    def copy_preprocessor_output_data(self):
        """
        Copy or link mesh_input file or directory to the execution directory,
        required both for the partitioner and the solver.
        """

        if self.exec_preprocess:
            return
        elif not (self.exec_partition or self.exec_solver):
            return

        if self.mesh_input != None:
            self.symlink(self.mesh_input,
                         os.path.join(self.exec_dir, 'mesh_input'))
        else:
            err_str = 'Error: no path name given for link to: ' + target
            raise RunCaseError(err_str)

    #---------------------------------------------------------------------------

    def copy_solver_data(self):
        """
        Copy solver data to the execution directory
        """

        if self.exec_solver == False:
            return

        if self.n_procs < 2:
            self.exec_partition = False
        elif self.exec_partition == False and self.partition_input != None:
            part_name = 'domain_number_' + str(self.n_procs)
            partition = os.path.join(self.partition_input, part_name)
            if os.path.isfile(partition):
                part_dir = os.path.join(self.exec_dir, 'partition')
                if not os.path.isdir(part_dir):
                    os.mkdir(part_dir)
                self.symlink(partition, os.path.join(part_dir, part_name))
            else:
                w_str = \
                    'Warning: no partitioning file is available\n' \
                    '         (no ' + partition + ').\n' \
                    '\n' \
                    '         Geometry-based partitioning will be used.\n'
                sys.stderr.write(w_str)

        # Parameters file

        if self.param != None:
            self.copy_data_file(self.param,
                                os.path.basename(self.param),
                                'parameters')

        # Restart files

        if self.restart_input_dir != None:

            if os.path.exists(self.restart_input_dir):

                if not os.path.isdir(self.restart_input_dir):
                    err_str = self.restart_input_dir + ' is not a directory.'
                    raise RunCaseError(err_str)
                else:
                    self.symlink(self.restart_input_dir,
                                 os.path.join(self.exec_dir, 'restart'))

        # Data for specific physics

        if self.thermochemistry_data != None:
            self.copy_data_file(self.thermochemistry_data,
                                'dp_thch',
                                'thermochemistry')
            if not os.path.isfile('JANAF'):
                self.copy_data_file(os.path.join(self.package.pkgdatadir,
                                                 'data',
                                                 'thch',
                                                 'JANAF'),
                                    'JANAF')

        if self.meteo_data != None:
            self.copy_data_file(self.meteo_data,
                                'meteo',
                                'meteo profile')
            # Second copy so as to have correct name upon backup
            if self.meteo_data != 'meteo':
                self.copy_data_file(self.meteo_data)

        # Presence of user input files

        if self.user_input_files != None:
            for f in self.user_input_files:
                self.copy_data_file(f)

    #---------------------------------------------------------------------------

    def run_preprocessor(self):
        """
        Runs the preprocessor in the execution directory
        """

        if self.exec_preprocess == False:
            return

        # Switch to execution directory

        cur_dir = os.path.realpath(os.getcwd())
        if cur_dir != self.exec_dir:
            os.chdir(self.exec_dir)

        mesh_id = None

        if len(self.meshes) > 1:
            mesh_id = 0
            destdir = 'mesh_input'
            if not os.path.isdir(destdir):
                os.mkdir(destdir)
            else:
                list = os.listdir(destdir)
                for f in list:
                    os.remove(os.path.join(destdir,f))

        # Run once per mesh

        for m in self.meshes:

            # Build command

            cmd = self.package.get_preprocessor()

            if (type(m) == tuple):
                cmd += ' --mesh ' + os.path.basename(m[0])
                for opt in m[1:]:
                    cmd += ' ' + opt

            else:
                cmd += ' --mesh ' + os.path.basename(m)

            if self.reorient:
                cmd += ' --reorient'

            if (mesh_id != None):
                mesh_id += 1
                cmd += ' --log preprocessor_%02d.log' % (mesh_id)
                cmd += ' --out ' + os.path.join('mesh_input',
                                                'mesh_%02d' % (mesh_id))
            else:
                cmd += ' --log'
                cmd += ' --out mesh_input'

            # Run command

            retcode = run_command(cmd)

            if retcode != 0:
                err_str = \
                    'Error running the preprocessor.\n' \
                    'Check the preprocessor.log file for details.\n\n'
                sys.stderr.write(err_str)

                self.exec_partition = False
                self.exec_solver = False

                self.error = 'preprocess'

                break

        # Revert to initial directory

        if cur_dir != self.exec_dir:
            os.chdir(cur_dir)

        return retcode

    #---------------------------------------------------------------------------

    def check_partitioner(self):
        """
        Tests if the partitioner is available and partitioning is defined.
        """

        if (self.exec_partition == False):
            return

        partitioner = self.package.get_partitioner()
        if not os.path.isfile(partitioner):
            if self.n_procs > 1:
                w_str = \
                    'Warning: ' + partitioner + ' not found.\n\n' \
                    'The partitioner may not have been installed' \
                    '  (this is the case if neither METIS nor SCOTCH ' \
                    ' are available).\n\n' \
                    'Partitioning by a space-filling curve will be used.\n\n'
                sys.stderr.write(w_str)
            self.exec_partition = False
            self.partition_n_procs = None

        if self.partition_list == None and not self.exec_solver:
            err_str = \
                'Unable to run the partitioner:\n' \
                'The list of required partitionings is not set.\n' \
                'It should contain the number of processors for which a\n' \
                'partition is required, or a list of such numbers.\n'
            raise RunCaseError(err_str)

        if os.path.isdir(os.path.join(self.exec_dir, 'mesh_input')):
            w_str = \
                'Warning: mesh_input is a directory\n\n' \
                'The Kernel must be run to concatenate its contents\n' \
                ' before graph-based partitioning is available.\n\n' \
                'Partitioning by a space-filling curve will be used.\n\n'
            sys.stderr.write(w_str)
            self.exec_partition = False
            self.partition_n_procs = None

    #---------------------------------------------------------------------------

    def run_partitioner(self):
        """
        Runs the partitioner in the execution directory
        """

        self.check_partitioner()
        if self.exec_partition == False:
            return

        # Build command

        cmd = self.package.get_partitioner()

        if self.partition_opts != None:
            cmd += ' ' + self.partition_opts

        if self.partition_list != None:
            cmd += ' ' + any_to_str(self.partition_list)

        if self.exec_solver and self.n_procs != None:
            np = self.n_procs
            if self.partition_list == None:
                cmd += ' ' + str(np)
            elif np > 1 and not np in self.partition_list:
                cmd += ' ' + str(np)

        # Run command

        cur_dir = os.path.realpath(os.getcwd())
        if cur_dir != self.exec_dir:
            os.chdir(self.exec_dir)

        retcode = run_command(cmd)

        if retcode != 0:
            err_str = \
                'Error running the partitioner.\n' \
                'Check the partition.log file for details.\n\n'
            sys.stderr.write(err_str)

            self.exec_solver = False

            self.error = 'partition'

        if cur_dir != self.exec_dir:
            os.chdir(cur_dir)

        return retcode

    #---------------------------------------------------------------------------

    def partitioner_args(self):
        """
        Returns a tuple indicating the partitioner's working directory,
        executable path, and associated command-line arguments.
        """
        # Working directory and executable path

        wd = self.exec_dir
        exec_path = self.package.get_partitioner()

        # Build kernel command-line arguments

        args = ''

        if self.partition_n_procs > 1:
            args += ' --mpi'

        if self.partition_opts != None:
            args += ' ' + self.partition_opts

        if self.partition_list != None:
            args += ' ' + any_to_str(self.partition_list)

        if self.exec_solver and self.n_procs != None:
            np = self.n_procs
            if self.partition_list == None:
                args += ' ' + str(np)
            elif np > 1 and not np in self.partition_list:
                args += ' ' + str(np)

        # Adjust for Valgrind if used

        if self.valgrind != None:
            args = self.solver_path + ' ' + args
            exec_path = self.valgrind

        return wd, exec_path, args

    #---------------------------------------------------------------------------

    def solver_args(self, **kw):
        """
        Returns a tuple indicating the solver's working directory,
        executable path, and associated command-line arguments.
        """

        wd = self.exec_dir              # Working directory
        exec_path = self.solver_path    # Executable

        # Build kernel command-line arguments

        args = ''

        if self.param != None:
            args += ' --param ' + self.param

        if self.logging_args != None:
            args += ' ' + self.logging_args

        if self.mode_args != None:
            args += ' ' + self.mode_args

        if self.name != None:
            args += ' --mpi --app-name ' + self.name
        elif self.n_procs > 1:
            args += ' --mpi'

        if 'syr_port' in kw:
            args += ' --syr-socket ' + str(kw['syr_port'])

        # Adjust for Valgrind if used

        if self.valgrind != None:
            args = self.solver_path + ' ' + args
            exec_path = self.valgrind + ' '

        return wd, exec_path, args

    #---------------------------------------------------------------------------

    def copy_preprocessor_results(self):
        """
        Retrieve preprocessor results from the execution directory
        and remove preprocessor input files if necessary.
        """

        # Determine if we should purge the execution directory

        purge = True
        if self.error == 'preprocess':
            purge = False

        # Remove input data if necessary

        if purge:
            for mesh in self.meshes:
                if mesh is None:
                    pass
                elif (type(mesh) == tuple):
                    mesh = mesh[0]
                try:
                    # Special case for meshes in EnSight format
                    base, ext = os.path.splitext(mesh)
                    m = os.path.join(self.exec_dir, mesh)
                    if ext == '.case':
                        f = open(os.path.join(self.exec_dir, mesh))
                        text = f.read(4096) # Should be largely sufficient
                        f.close()
                        l = re.search('^model:.*$', text, re.MULTILINE)
                        g = (l.group()).split()[1]
                        os.remove(os.path.join(self.exec_dir, g))
                    os.remove(m)
                except Exception:
                    pass

        # Copy log file(s) first

        if len(self.meshes) == 1:
            f = os.path.join(self.exec_dir, 'preprocessor.log')
            if os.path.isfile(f):
                self.copy_result(f, purge)
        else:
            mesh_id = 0
            for m in self.meshes:
                mesh_id += 1
                f = os.path.join(self.exec_dir,
                                 'preprocessor_%02d.log' % (mesh_id))
                if os.path.isfile(f):
                    self.copy_result(f, purge)

        # Copy output if required (only purge if we have no further
        # errors, as it may be necessary for future debugging).

        if self.error != '':
            purge = False

        f = os.path.join(self.exec_dir, 'mesh_input')

        if not self.exec_solver:
            if os.path.isfile(f) or os.path.isdir(f):
                self.copy_result(f, purge)
        elif purge:
            self.purge_result(f)

    #---------------------------------------------------------------------------

    def copy_partition_results(self):
        """
        Retrieve partition results from the execution directory
        """

        # Determine if we should purge the execution directory

        purge = True
        if self.error == 'partition':
            purge = False

        # Copy log file first.

        f = os.path.join(self.exec_dir, 'partition.log')
        if os.path.isfile(f):
            self.copy_result(f, purge)

        # Copy output if required (only purge if we have no further
        # errors, as it may be necessary for future debugging).

        if self.error != '':
            purge = False

        d = os.path.join(self.exec_dir, 'partition')

        if not self.exec_solver:
            if os.path.isdir(d):
                self.copy_result(d, purge)
        elif purge:
            self.purge_result(d)

        # Purge mesh_input if it was used solely by the partitioner

        if not (self.exec_preprocess or self.exec_solver):
            if self.error == '':
                self.purge_result('mesh_input')

    #---------------------------------------------------------------------------

    def copy_solver_results(self):
        """
        Retrieve solver results from the execution directory
        """

        # Determine all files present in execution directory

        dir_files = os.listdir(self.exec_dir)

        # Determine if we should purge the execution directory

        valid_dir = False
        purge = True

        if self.error != '':
            purge = False

        # Determine patterns from previous stages to ignore or possibly remove

        purge_list = []

        for f in ['mesh_input', 'partition', 'restart']:
            if f in dir_files:
                purge_list.append(f)

        # Determine files from this stage to ignore or to possibly remove

        for f in [self.package.solver, 'run_solver.sh']:
            if f in dir_files:
                purge_list.append(f)
        purge_list.extend(fnmatch.filter(dir_files, 'core*'))

        if self.user_scratch_files != None:
            for f in self.user_scratch_files:
                purge_list.extend = fnmatch.filter(dir_files, f)

        for f in purge_list:
            dir_files.remove(f)
            if purge:
                self.purge_result(f)

        if len(purge_list) > 0:
            valid_dir = True

        # Copy user sources, compile log, and xml file if present

        for f in [self.package.srcdir, 'compile.log', self.param]:
            if f in dir_files:
                valid_dir = True
                self.copy_result(f, purge)
                dir_files.remove(f)

        # Copy log files

        log_files = fnmatch.filter(dir_files, 'listing*')
        log_files.extend(fnmatch.filter(dir_files, '*.log'))
        log_files.extend(fnmatch.filter(dir_files, 'error*'))

        for f in log_files:
            self.copy_result(f, purge)
            dir_files.remove(f)

        if (len(log_files) > 0):
            valid_dir = True

        # Copy checkpoint files (in case of full disk, copying them
        # before other large data such as postprocessing output
        # increases chances of being able to continue).

        cpt = 'checkpoint'
        if cpt in dir_files:
            valid_dir = True
            self.copy_result(cpt, purge)
            dir_files.remove(cpt)

        # Now copy all other files

        if not valid_dir:
            return

        for f in dir_files:
            self.copy_result(f, purge)

#-------------------------------------------------------------------------------

# SYRTHES 3 coupling

class syrthes3_domain(base_domain):

    def __init__(self,
                 package,
                 name = None,
                 echo_comm = None,             # coupling verbosity
                 coupling_mode = 'MPI',        # 'MPI' or 'sockets'
                 coupled_apps = None):         # coupled domain names
                                               # if n_domains > 1


        base_domain.__init__(self, package, name, 1, 1, 1)

        self.log_file = 'syrthes.log'

        # Directories, and files in case structure

        self.data_dir = None
        self.result_dir = None
        self.src_dir = None
        self.echo_comm = echo_comm

        self.set_coupling_mode(coupling_mode)

        self.coupled_apps = coupled_apps

    #---------------------------------------------------------------------------

    def set_case_dir(self, case_dir):

        base_domain.set_case_dir(self, case_dir)

        # Names, directories, and files in case structure

        # No RESU dir for SYRTHES 3 case, as toplevel RESU_COUPLING
        # is used in coupled case, and the script does not handle
        # standalone SYRTHES 3 calculations (which require a different
        # executable)

        self.result_dir = None

    #---------------------------------------------------------------------------

    def set_coupling_mode(self, coupling_mode):

        # Check that coupling mode is either 'MPI' or 'sockets'
        coupling_modes = ('MPI', 'sockets')
        if coupling_mode not in coupling_modes:
            err_str = \
                'SYRTHES3 coupling mode "' + str(coupling_mode) + '" unknown.\n' \
                + 'Allowed modes: ' + str(coupling_modes) + '.\n'
            raise RunCaseError(err_str)

        # Coupling mode
        self.coupling_mode = coupling_mode

    #---------------------------------------------------------------------------

    def compile_and_link(self):
        """
        Compile and link user subroutines if necessary
        """

        # Check if there are files to compile in source path

        dir_files = os.listdir(self.src_dir)

        src_files = (fnmatch.filter(dir_files, '*.c')
                     + fnmatch.filter(dir_files, '*.[fF]'))

        copy_dir = None
        exec_src = None

        if len(src_files) > 0:

            # Add header files to list so as not to forget to copy them

            src_files = src_files + fnmatch.filter(dir_files, '*.h')

            # Copy source files to execution directory

            exec_src = os.path.join(self.exec_dir, 'src')
            os.mkdir(exec_src)

            for f in src_files:
                src_file = os.path.join(self.src_dir, f)
                dest_file = os.path.join(exec_src, f)
                shutil.copy2(src_file, dest_file)

        log_name = os.path.join(self.exec_dir, 'compile.log')
        log = open(log_name, 'w')

        retval = cs_compile.compile_and_link_syrthes(self.package,
                                                     exec_src,
                                                     self.exec_dir,
                                                     stdout=log,
                                                     stderr=log)

        log.close()

        if retval != 0:
            # In case of error, copy source to results directory now,
            # as no calculation is possible, then raise exception.
            for f in [self.package.srcdir, 'compile.log']:
                self.copy_result(f)
            raise RunCaseError('Compile or link error.')

        self.solver_path = os.path.join(self.exec_dir, 'syrthes')

    #---------------------------------------------------------------------------

    def solver_args(self, **kw):
        """
        Returns a tuple indicating SYRTHES's working directory,
        executable path, and associated command-line arguments.
        """

        wd = self.exec_dir              # Working directory
        exec_path = self.solver_path    # Executable

        # Build kernel command-line arguments

        args = ' --log syrthes.log'
        if self.echo_comm != None:
            args += ' --echo-comm ' + str(self.echo_comm)

        if self.coupling_mode == 'MPI':
            args += ' --app-name ' + os.path.basename(self.case_dir)
            if self.coupled_apps != None:
                args += ' --comm-mpi ' + any_to_str(self.coupled_apps)
            else:
                args += ' --comm-mpi '

        elif self.coupling_mode == 'sockets':
            if 'host_port' in kw:
                args += ' --comm-socket ' + any_to_str(kw['host_port'])

        # handled directly

        # Adjust for Valgrind if used

        if self.valgrind != None:
            args = self.solver_path + ' ' + args
            exec_path = self.valgrind

        return wd, exec_path, args

    #---------------------------------------------------------------------------

    def prepare_data(self):
        """
        Copy data to the execution directory
        """

        cwd = os.getcwd()
        os.chdir(self.exec_dir)

        syrthes_env = os.path.join(self.data_dir, 'syrthes.env')

        cmd = self.package.get_runcase_script('runcase_syrthes')
        cmd += ' -copy-data -syrthes-env=' + syrthes_env

        if run_command(cmd) != 0:
            raise RunCaseError

        os.chdir(cwd)

    #---------------------------------------------------------------------------

    def preprocess(self):
        """
        Empty for SYRTHES 3
        """
        pass

    #---------------------------------------------------------------------------

    def preprocess(self):
        """
        Run preprocessing stages (empty for SYRTHES 3)
        """

        return

    #---------------------------------------------------------------------------

    def copy_results(self):
        """
        Retrieve results from the execution directory
        """

        dir_files = os.listdir(self.src_dir)

        purge = True
        if self.error != '':
            purge = False

        # Copy user sources, compile log, and execution log if present

        for f in ['src', 'compile.log', 'syrthes.log']:
            if f in dir_files:
                self.copy_result(f, purge)
                dir_files.remove(f)

        if self.exec_dir == self.result_dir:
            return

        cwd = os.getcwd()
        os.chdir(self.exec_dir)

        cmd = self.package.get_runcase_script('runcase_syrthes') \
            + ' -copy-results -result-dir=' + self.result_dir

        if run_command(cmd) != 0:
            raise RunCaseError

        os.chdir(cwd)

#-------------------------------------------------------------------------------

# SYRTHES 4 coupling

class syrthes_domain(base_domain):

    def __init__(self,
                 package,
                 cmd_line = None,     # Command line to define optional syrthes4 behaviour
                 name = None,
                 param = 'syrthes.data',
                 log_file = None,
                 n_procs = None,
                 n_procs_min = 1,
                 n_procs_max = None,
                 n_procs_radiation = None):

        base_domain.__init__(self,
                             package,
                             name,
                             n_procs,
                             n_procs_min,
                             n_procs_max)

        self.n_procs_radiation = n_procs_radiation

        # Additional parameters for Code_Saturne/SYRTHES coupling
        # Directories, and files in case structure

        self.cmd_line = cmd_line
        self.param = param

        self.logfile = log_file
        if self.logfile == None:
            self.logfile = 'syrthes.log'

        self.case_dir = None
        self.exec_dir = None
        self.data_dir = None
        self.src_dir = None
        self.result_dir = None
        self.echo_comm = None

        self.set_coupling_mode('MPI')

        # Generation of SYRTHES case deferred until we know how
        # many processors are really required

        self.syrthes_case = None

    #---------------------------------------------------------------------------

    def set_case_dir(self, case_dir):

        base_domain.set_case_dir(self, case_dir)

        # Names, directories, and files in case structure

        self.data_dir = self.case_dir
        self.src_dir = self.case_dir

    #---------------------------------------------------------------------------

    def set_coupling_mode(self, coupling_mode):

        # Check that coupling mode is either 'MPI' or 'sockets'
        coupling_modes = ('MPI')
        if coupling_mode not in coupling_modes:
            err_str = \
                'SYRTHES4 coupling mode "' + str(coupling_mode) + '" unknown.\n' \
                + 'Allowed modes: ' + str(coupling_modes) + '.\n'
            raise RunCaseError(err_str)

        # Coupling mode
        self.coupling_mode = coupling_mode

    #---------------------------------------------------------------------------

    def set_exec_dir(self, exec_dir):

        if os.path.isabs(exec_dir):
            self.exec_dir = exec_dir
        else:
            self.exec_dir = os.path.join(self.case_dir, 'RESU', exec_dir)

        self.exec_dir = os.path.join(self.exec_dir, self.name)

        if not os.path.isdir(self.exec_dir):
            os.mkdir(self.exec_dir)

    #---------------------------------------------------------------------------

    def set_result_dir(self, name, given_dir = None):

        if given_dir == None:
            self.result_dir = os.path.join(self.result_dir,
                                           'RESU_' + self.name,
                                           name)
        else:
            self.result_dir = os.path.join(given_dir, self.name)

        if not os.path.isdir(self.result_dir):
            os.makedirs(self.result_dir)

    #---------------------------------------------------------------------------

    def solver_args(self, **kw):
        """
        Returns a tuple indicating SYRTHES's working directory,
        executable path, and associated command-line arguments.
        """

        wd = self.exec_dir              # Working directory
        exec_path = self.solver_path    # Executable

        # Build kernel command-line arguments

        args = ''

        args += ' -d ' + self.syrthes_case.data_file
        args += ' -n ' + str(self.syrthes_case.n_procs)

        if self.syrthes_case.n_procs_ray > 0:
            args += ' -r ' + str(self.n_procs_ray)

        if self.coupling_mode == 'MPI':

            args += ' --name ' + self.name

        # Output to a logfile
        # args += ' --log ' + self.logfile

        # Adjust for Valgrind if used

        if self.valgrind != None:
            args = self.solver_path + ' ' + args
            exec_path = self.valgrind

        return wd, exec_path, args

    #---------------------------------------------------------------------------

    def prepare_data(self):
        """
        Fill SYRTHES domain structure
        Copy data to the execution directory
        Compile and link syrthes executable
        """

        # Build command-line arguments

        args = '-d ' + os.path.join(self.case_dir, self.param)
        args += ' -l ' + self.logfile
        args += ' --name ' + self.name

        if self.n_procs != None and self.n_procs != 1:
            args += ' -n ' + str(self.n_procs)

        if self.n_procs_radiation > 0:
            args += ' -r ' + str(self.n_procs_radiation)

        if self.data_dir != None:
            args += ' --data-dir ' + str(self.data_dir)

        if self.src_dir != None:
            args += ' --src-dir ' + str(self.src_dir)

        if self.exec_dir != None:
            args += ' --exec-dir ' + str(self.exec_dir)

        if self.cmd_line != None and len(self.cmd_line) > 0:
            args += ' ' + self.cmd_line

        # Define syrthes case structure

        try:
            config = ConfigParser.ConfigParser()
            config.read([self.package.get_configfile(),
                         os.path.expanduser('~/.' + self.package.configfile)])
            syr_datapath = os.path.join(config.get('install', 'syrthes'),
                                        os.path.join('share', 'syrthes'))
            sys.path.insert(0, syr_datapath)
            import syrthes
        except Exception:
            raise RunCaseError("Cannot locate SYRTHES installation.\n")
            sys.exit(1)

        self.syrthes_case = syrthes.process_cmd_line(args.split())

        # Read data file and store parameters

        self.syrthes_case.read_data_file()

        # Build exec_srcdir

        exec_srcdir = os.path.join(self.exec_dir, 'src')
        os.makedirs(exec_srcdir)

        # Preparation of the execution directory and compile and link executable

        compile_logname = os.path.join(self.exec_dir, 'compile.log')

        retval = self.syrthes_case.prepare_run(exec_srcdir, compile_logname)

        self.copy_result(compile_logname)

        if retval != 0:
            err_str = '\n   Error during the SYRTHES preparation step\n'
            if retval == 1:
                err_str += '   Error during data copy\n'
            elif retval == 2:
                err_str += '   Error during syrthes compilation and link\n'
                # Copy source to results directory, as no run is possible
                for f in ['src', 'compile.log']:
                    self.copy_result(f)
            raise RunCaseError(err_str)

        # Set executable

        self.solver_path = os.path.join(self.exec_dir, 'syrthes')

    #---------------------------------------------------------------------------

    def preprocess(self):
        """
        Read syrthes.data file
        Partition mesh for parallel run if required by user
        """

        # Sumary of the parameters
        self.syrthes_case.dump()

        # Initialize output file if needed
        self.syrthes_case.logfile_init()

        # Pre-processing (including partitioning only if SYRTHES
        # computation is done in parallel)
        retval = self.syrthes_case.preprocessing()
        if retval != 0:
            err_str = '\n  Error during the SYRTHES preprocessing step\n'
            raise RunCaseError(err_str)

    #---------------------------------------------------------------------------

    def copy_results(self):
        """
        Retrieve results from the execution directory
        """

        if self.exec_dir == self.result_dir:
            return

        retval = self.syrthes_case.save_results(save_dir = self.result_dir,
                                                horodat = False,
                                                overwrite = True)
        if retval != 0:
            err_str = '\n   Error saving SYRTHES results\n'
            raise RunCaseError(err_str)

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
