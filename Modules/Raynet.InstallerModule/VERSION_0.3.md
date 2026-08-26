# Raynet Installer Framework 0.3 — conservative rebuild

This build is reconstructed from the tested 0.2 Fix1 baseline.

Implemented:
- Public\Config\RaynetInstaller.ini
- logging threshold: DEBUG / INFO / SUCCESS / WARNING / ERROR
- package startup header
- automatic package root capture; no package-script path plumbing required
- relative source path normalization in Add-RaynetComponent
- Raynet_CopyFiles (Raynet_CopyFile retained as compatibility alias)
- Raynet_ModifyXML
- existing plugin-style Type -> Invoke-RaynetType dispatch retained
- existing dynamic Raynet_* help retained
- Raynet_Service and Raynet_ConfigureService remain separate
