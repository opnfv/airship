.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Open Platform for NFV Project, Inc. and its contributors

=============================================
OPNFV Airship Installer Project Release Notes
=============================================

This document provides the release notes for Airship Installer Project.

Version History
---------------

+--------------------+--------------------+--------------------+----------------------+
| **Date**           | **Version**        | **Author**         | **Comment**          |
+--------------------+--------------------+--------------------+----------------------+
| 2019-11-17         | 0.1.0              | Bin Hu             | Initial framework    |
+--------------------+--------------------+--------------------+----------------------+
| 2019-12-19         | 1.0.0              | Bin Hu             | Iruya release        |
+--------------------+--------------------+--------------------+----------------------+
| 2020-12-01         | 2.0.0              | James Gu           | Jerma release        |
+--------------------+--------------------+--------------------+----------------------+

Release Data
------------

+--------------------------------------+--------------------------------------+
| **Project**                          | Airship Installer                    |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | opnfv-10.0.0                         |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Jerma 10.0                           |
+--------------------------------------+--------------------------------------+
| **Release date**                     | December 1st, 2020                   |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Jerma 10.0 Release             |
+--------------------------------------+--------------------------------------+

Important Notes
---------------

Please visit https://www.airshipit.org/ for upstream Airship Project.

Summary
-------

This is the Jerma release of the Airship Installer as part of OPNFV, including:

* deployment of an NFVi with Airship Installer in a hardware infrastructure.

Please refer to our:

* `Installation Guide <../installation/index.html>`_

Known Limitations, Issues and Workarounds
-----------------------------------------

System Limitations
^^^^^^^^^^^^^^^^^^

In the default configuration of Airship 1.8, OVS-DPDK is used to provide
high-performance networking between instances on OpenStack compute nodes.
Due to known issues and performance concerns between Neutron and OVS-DPDK,
the default configuration of Airship 1.8 does not support Neutron floating
ip and Neutron self-service tenant network.

Known Issues
^^^^^^^^^^^^

Nova live migration is not supported because the functionality is not
avaialable yet in OpenStack Helm project.

Workarounds
^^^^^^^^^^^

N/A.

Test Result
-----------

Please reference Functest project documentation for test results with the
Airship Installer.

References
----------

For more information on the OPNFV Jerma release, please see:

http://www.opnfv.org/software

