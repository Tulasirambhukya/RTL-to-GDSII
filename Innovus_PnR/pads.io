(globals
    version = 3
    io_order = clockwise
)

(iopad

    #################################################
    # TOP LEFT CORNER
    #################################################

    (topleft
        (inst name="CORNER1" cell=PADCORNER)
    )

    #################################################
    # LEFT SIDE
    #################################################

    (left

        (inst name="clk"        cell=PADI)
        (inst name="rst"        cell=PADI)

        (inst name="data_in0"   cell=PADI)
        (inst name="data_in1"   cell=PADI)

        (inst name="VDD_L"      cell=PADVDD1)
        (inst name="VSS_L"      cell=PADVSS1)

        (inst name="data_out0"  cell=PADO)
        (inst name="data_out1"  cell=PADO)
    )

    #################################################
    # TOP RIGHT CORNER
    #################################################

    (topright
        (inst name="CORNER2" cell=PADCORNER)
    )

    #################################################
    # TOP SIDE
    #################################################

    (top

        (inst name="wr_en"      cell=PADI)
        (inst name="rd_en"      cell=PADI)

        (inst name="data_in2"   cell=PADI)
        (inst name="data_in3"   cell=PADI)

        (inst name="VDD_T"      cell=PADVDD1)
        (inst name="VSS_T"      cell=PADVSS1)

        (inst name="data_out2"  cell=PADO)
        (inst name="data_out3"  cell=PADO)
    )

    #################################################
    # BOTTOM RIGHT CORNER
    #################################################

    (bottomright
        (inst name="CORNER3" cell=PADCORNER)
    )

    #################################################
    # RIGHT SIDE
    #################################################

    (right

        (inst name="data_in4"   cell=PADI)
        (inst name="data_in5"   cell=PADI)

        (inst name="data_out4"  cell=PADO)
        (inst name="data_out5"  cell=PADO)

        (inst name="VDD_R"      cell=PADVDD1)
        (inst name="VSS_R"      cell=PADVSS1)

        (inst name="full"       cell=PADO)
        (inst name="empty"      cell=PADO)
    )

    #################################################
    # BOTTOM LEFT CORNER
    #################################################

    (bottomleft
        (inst name="CORNER4" cell=PADCORNER)
    )

    #################################################
    # BOTTOM SIDE
    #################################################

    (bottom

        (inst name="data_in6"   cell=PADI)
        (inst name="data_in7"   cell=PADI)

        (inst name="data_out6"  cell=PADO)
        (inst name="data_out7"  cell=PADO)

        (inst name="test_mode"  cell=PADI)
        (inst name="spare1"     cell=PADI)

        (inst name="VDD_B"      cell=PADVDD2)
        (inst name="VSS_B"      cell=PADVSS2)
    )
)