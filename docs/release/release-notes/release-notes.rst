.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Anuket and its contributors

=============================================
Anuket Airship Installer Project Release Notes
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
| 2021-07-01         | 3.0.0              | James Gu           | Kali release         |
+--------------------+--------------------+--------------------+----------------------+

Release Data
------------

+--------------------------------------+--------------------------------------+
| **Project**                          | Airship Installer                    |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | Kali                                 |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Kali                                 |
+--------------------------------------+--------------------------------------+
| **Release date**                     | July 1st, 2021                       |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | Anuket Kali Release                  |
+--------------------------------------+--------------------------------------+

Important Notes
---------------

Please visit https://www.airshipit.org/ for upstream Airship Project.

Summary
-------

This is the Kali release of the Airship Installer as part of Anuket, including:

* deployment of an NFVi with Airship Installer in a hardware infrastructure.

Please refer to our:

* `Installation Guide <../installation/index.html>`_

Known Limitations, Issues and Workarounds
-----------------------------------------

System Limitations
^^^^^^^^^^^^^^^^^^

In the default configuration of Airship Treasuremap 1.8, OVS-DPDK is used
to provide high-performance networking between instances on OpenStack
compute nodes. Due to known issues and performance concerns between
OpenStack Neutron and OVS-DPDK, the default configuration of deployed
OpenStack does not support Neutron floating ip and Neutron self-service
tenant network.

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

N/A.

