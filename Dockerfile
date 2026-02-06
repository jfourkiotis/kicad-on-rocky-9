FROM rockylinux:9

RUN dnf -y update && \
    dnf -y install dnf-plugins-core epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf -y install --allowerasing \
      git cmake ninja-build gcc gcc-c++ make python3 python3-devel swig \
      curl file patchelf xz bzip2 which pkgconfig \
      autoconf automake libtool bison flex perl \
      gcc-gfortran \
      gettext-devel \
      gtk3-devel \
      mesa-libGL-devel mesa-libEGL-devel mesa-libGLU-devel \
      libX11-devel libXrender-devel libXext-devel libXrandr-devel libXi-devel \
      libXcursor-devel libXinerama-devel libXfixes-devel libXxf86vm-devel \
      cairo-devel pixman-devel \
      freetype-devel harfbuzz-devel fontconfig-devel \
      glew-devel glm-devel \
      zlib-devel libzstd-devel libcurl-devel \
      libgit2-devel libssh2-devel openssl-devel \
      boost-devel \
      protobuf-devel protobuf-compiler \
      unixODBC-devel \
      libsecret-devel \
      libpng-devel libjpeg-turbo-devel libtiff-devel \
      tcl-devel tk-devel \
      wayland-devel wayland-protocols-devel \
      libdecor-devel \
      libXdamage-devel libXcomposite-devel libXtst-devel \
      libdrm-devel \
      libuuid-devel \
      libnsl2-devel \
      libffi-devel \
      readline-devel \
      ncurses-devel \
      libedit-devel \
      ccache \
      xorg-x11-server-Xvfb && \
    dnf -y clean all

WORKDIR /src
