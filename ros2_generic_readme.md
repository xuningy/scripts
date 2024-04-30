# Installation
For ros2 related python installation, we have to use `setuptools=58.2.0`. See discussion [here](https://answers.ros.org/question/396439/setuptoolsdeprecationwarning-setuppy-install-is-deprecated-use-build-and-pip-and-other-standards-based-tools/) and official colcon comment [here](https://github.com/colcon/colcon-core/issues/454#issuecomment-1262592774).

1. Check python version and `setuptools` version:

    ```
    ~/ros2_utils$ python3
    Python 3.10.12 (main, Nov 20 2023, 15:14:05) [GCC 11.4.0] on linux
    Type "help", "copyright", "credits" or "license" for more information.
    >>> import setuptools
    >>> print(setuptools.__version__)
    69.5.1
    ```
2. If `setuptools` version is above 58.2.0, downgrade it.
   ```
   pip install setuptools==58.2.0
   ```
3. Add this folder to your ros2 work space.

# To Run
```
source  install/local_setup.bash
ros2 run se2_controller pure_pursuit_controller
```
