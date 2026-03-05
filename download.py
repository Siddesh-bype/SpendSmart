import urllib.request
import os

assets_dir = "./stitch_assets"
os.makedirs(assets_dir, exist_ok=True)

resources = [
    ("splash",
     "https://lh3.googleusercontent.com/aida/AOfcidVLRbzbwhK6O_owf-7iFuj-CUs9rcAZvjMYCdJtCnYlKngfQtktdilQ7UWNdIafCmDn6ZQ8Txz0ltpcl9j8lqwRdCrpRRXUfaPVboxyN--Ryn_EMWPf-3fmTkcVOhAqSLDfvp80CQvgWf_BH8fxZMSibI5MhqbCDskoZtj0EwJjhUrm03NilUJvGMxTThoaXhXJpCwZTYaI97zT66moNKcfoosAPMJWeIhO4cT0MBgRgIM4KJyzJROpGn0",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzJiNjgyYjBjNTM0ZjQ5YzBiZjY1YzRhZGMwMmFlODIzEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("dashboard",
     "https://lh3.googleusercontent.com/aida/AOfcidUPro_VpoeOiOa_yO9XXiSU92DRbBryPrjuMQRgkCgl6KFTUQoc3e511wyZZjniUA9MBzMD2T1n9VtCiAkuYUzdfm2AZkoqnXAjhTyBXFHdXk39mJsm9jdBk--8hbJJrq-HU6xYt8INuuLT1TiutgrHNSVDBPvtU-GI8Jf675rP8BnKiLeMAj1a5vnR5J3OIs_k3WSbMAmx3t3V0H8LvQ2ncVpkiNK1kiYaz_x4I3-MMbn5mfx2UfcHx9n2",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzhiZmJiYmFkYWQ3OTQ5ZGRiODMyM2NiZmQ4ODE1MTI3EgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("settings",
     "https://lh3.googleusercontent.com/aida/AOfcidXtgUH2wopZHumh1QlejDGVjrCuctkKAGXy5Sg-yiJ8Ca73M408TR6_VpB0QZ8Tu-edRXm24_AtKUgYsVgU8AZpQJXQLoYWmtrcGf8LxeDgEhoHOcJ7Cj0Og0F6fspcYUvvPqcitBK_-_KXCfWyzbtHDqEn2WzorDjdL4z3szqYvDa5MQvBYOEzYwko2HpwSkOzc72__p1r5cLu_r4XNOUtHn5Mf-wmdgGewdNWh9qgjFDfY3BcvclbuIer",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sX2NiZjE4N2JmNDMzYjRhYzRhMjNjNGRmNWM1OTMzNjc4EgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("history",
     "https://lh3.googleusercontent.com/aida/AOfcidXzj-oXFX6T7HpcGX93HAAjZbUZU6_mBvy2FLbsXZLuVgc-buDVMX9STeBZVIZPylwQGX0GVy-uKXK4YtUz2mTDzAauZe7rw4iUey6393rpqEnPkyq64vDQP17TjzUetWpWnbjRfnapjGiULSkf-YEn5KMxvKO4ZuMpvoZP2igwujDQcixRNVDr9Ui7XU2TwiZ33E2x7omX8xHKVkoSTWW-qkGEaguU0x2Gf-cIqE4wNPaoDLIDXCZ_buVX",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzhmOTM0MmU0ODZkOTRlYWQ4ODUyMDcyMmI0ZWJlZTk2EgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("add_manual",
     "https://lh3.googleusercontent.com/aida/AOfcidU1JHMIIgQIcQRrcZxeP1Xs19C3qaLfGI_og7nsRngR3cHzUyLNR3rrKwj06W4NHqxY0leNeukNwANI7uYuHjVeShbqN8pbD8-wNY8MzUIxmfeDDlfnUpPrKBSF3af9iqpN-S6ZMsLsl9vte4dVXQLfkE2-b_fXmmADhfO415IyrbCVQhD9djnvNfW90F-5rzAGOQXmVuSyk70tfrKsADWgAZLT5tpokEXN5U4PAGsvSFNmHYzu1ooejCdQ",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sX2ZkMDQwN2Y2ZmMzYjQ2Y2E4MWNhN2MwYjgyNzZhZWZjEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("budget_setup",
     "https://lh3.googleusercontent.com/aida/AOfcidUh61F_AhUeUXkGlS9ZUxTejjGQDxGYvO36DdZ6E8eBUyWAnV13JFCEpT4jgPsRNrEawNYq6gz3XWnpkVDvtE5XLtwQshVE6qF6frMKjujxtbtW8Kk223LH66gXadaQ5Y_FocZgAUpSIpeTQOxCavKNi2IUYKJV7CGTZ1bX7-o4a3hEK64puv8nc5OcZSTl0g8QD4YQ5j20yWEp8MnUJugj6yNiaSLxYrqqmTUwN7vJHJLWUo5uS68zOxqB",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzYxODI2OTJkOWVkMTQ1NDk4NTBhMmY4MDg5OWU5ODgyEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("pending",
     "https://lh3.googleusercontent.com/aida/AOfcidWNuflShNn6ImRGSEDkZH8ePx0xLNW8qtCem-u4WhDG9-1GWN6SW_-JlXXU1_qa-hnjM3jesV0P1zJUjWQuK9TKMpGVucxtG-zSa7fnhKWd3HH3EDPBo7mId8Ltn_lnM_m3vqQnRCQSZJNTc6JuNLSNkpoYE4iWICmwsohAQ15knUS9gmwuWEaQgMRHIzMHk_vYzK6JhA1W9Thurp_DnfM0_JtomjgVfSJW3UVXUdF9mmOBHgFytRysZro",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzA5ZTA0OGU4MmE1MDRhODVhODlmNTdjZmM2NjMzODkyEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("analytics",
     "https://lh3.googleusercontent.com/aida/AOfcidUxZVJrODeFgadD3TnW7XGdtX--NHfljsX8z7YVzj8nf7FtkArV3IXCrhgSWgb4s4vbyfW7rOXcC666CKnW2PBudqyiYKqmZmyjoLstDA8ea_dNQe4frsotvQg3XG_67Kgk-gafeRcbIEmjHZY_17rW3V_qSeAyJO1sqC_j2f-LVWH-SbIRS_1wyXf8EGp4JIfszPhVCpKwwStsplnL7irhJoJ1h8vNU6RqoVkO8zqUG2HNIwZoEhhESpfl",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzk0MDk4NTI1MmUwNzQyMGI4NDQ2YTlkZTY5OWQ1ZWMxEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("new_transaction",
     "https://lh3.googleusercontent.com/aida/AOfcidVejzU14PTDfRyKPUu37exJhsscPEr6KTQg5G1F2zmmwuAJy4eS_AYbiO0M8o_BhP6OinEFmaC34Aez5OO4xbyHV5NtXKPKNfP7km_SrTyB00GwXK3vO-iJht98tz7PZjI_Mmohs822-gjeNjyiDXv3RJ7C1mgnHX-BJq3VG4g3vHxEwBsfmSKZ-hy7vJUeU8C3Gk2ejIg7kpMYLo8RZcBKIKZdK8xD6N1Yv7t9wXFNThTiv7_XCbMe-JI",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sXzkwOTdlZDJkMmE2NjRjNGM5NTQ0Njg2MjZkMDcyM2NjEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
    ("onboarding",
     "https://lh3.googleusercontent.com/aida/AOfcidXMwzS_COSdDRWpuVPwyC-wWmwVGeNPK7yNhHWpqeEKanbaR6ko1l3JjZ2-tXiA8ZviHLYlHpnT889FMUhKb1n3xV9gdULAfIYoHXqdCYX1J-D5vj2XmPy6clfTt7YtyK24mDhAVLY89BPOMhIW9FmFbstHoPjzzuyEo2bNyZwiDdSl3qPZQW7-vtX4sGji0PpfGKZSsG3PlZSeRRQjWiuiI6DO5m_VpE68rKhYzfQpK8iXDrxOvtStkbVN",
     "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ8Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpbCiVodG1sX2YyMDI1ZDE2MjUwMTQ5ZGI5ODk2N2E3NWUxOWY4ZDllEgsSBxDTtZXTkAMYAZIBJAoKcHJvamVjdF9pZBIWQhQxMzU2ODI5NDM3MTgwOTQxMDU2NQ&filename=&opi=89354086"),
]

for name, img_url, html_url in resources:
    print(f"Downloading {name}...")
    
    img_req = urllib.request.Request(img_url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(img_req) as response:
            with open(f"{assets_dir}/{name}.png", "wb") as f:
                f.write(response.read())
    except Exception as e:
        print(f"Failed to dl img for {name}: {e}")
        
    html_req = urllib.request.Request(html_url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(html_req) as response:
            with open(f"{assets_dir}/{name}.html", "wb") as f:
                f.write(response.read())
    except Exception as e:
        print(f"Failed to dl html for {name}: {e}")

print("Done downloading!")
