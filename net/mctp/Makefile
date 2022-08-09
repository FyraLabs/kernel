# SPDX-License-Identifier: GPL-2.0
obj-$(CONFIG_MCTP) += mctp.o
mctp-objs := af_mctp.o device.o route.o neigh.o

# tests
mctp_test-$(CONFIG_MCTP_TEST) += device.o test/utils.o
