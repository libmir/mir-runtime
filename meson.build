project('mir-runtime', 'd', version : '0.0.2', license: 'BSL-1.0')

add_project_arguments([
    '-dip25',
    '-dip1000',
    '-dip1008',
    ], language: 'd')

mir_runtime_dir = include_directories('source/')

mir_core_dep = dependency('mir-core', fallback : ['mir-core', 'mir_core_dep'])

required_deps = [mir_core_dep]

mir_runtime_src = [
    'source/mir/appender.d',
    'source/mir/exception.d',
    'source/mir/format_impl.d',
    'source/mir/format.d',
    'source/mir/parse.d',
]

mir_runtime_lib = library(meson.project_name(),
    mir_runtime_src,
    include_directories: mir_runtime_dir,
    install: true,
    version: meson.project_version(),
    dependencies: required_deps,
)

mir_runtime_dep = declare_dependency(
    link_with: [mir_runtime_lib],
    include_directories: mir_runtime_dir,
    dependencies: required_deps,
)

install_subdir('source/',
    strip_directory : true,
    install_dir: 'include/d/' + meson.project_name(),
)

import('pkgconfig').generate(mir_runtime_lib,
    description: 'Mir runtime - Base software building blocks and conventions.',
    subdirs: 'd/' + meson.project_name(),
)

if get_option('with_test')

    mir_runtime_test_exe = executable(meson.project_name() + '-test',
        mir_runtime_src,
        include_directories: mir_runtime_dir,
        d_unittest: true,
        d_module_versions: ['mir_test'],
        link_args: '-main',
        dependencies: required_deps,
    )

    test(meson.project_name() + '-test', mir_runtime_test_exe)

endif
