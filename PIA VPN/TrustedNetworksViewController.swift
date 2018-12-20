//
//  TrustedNetworksViewController.swift
//  PIA VPN
//
//  Created by Jose Antonio Blaya Garcia on 18/12/2018.
//  Copyright © 2018 London Trust Media. All rights reserved.
//

import UIKit
import PIALibrary

class TrustedNetworksViewController: AutolayoutViewController {

    @IBOutlet private weak var tableView: UITableView!
    private var availableNetworks: [String] = []
    private var trustedNetworks: [String] = []
    private let currentNetwork: String? = nil
    private var hotspotHelper: PIAHotspotHelper!
    private lazy var switchWiFiProtection = UISwitch()
    private lazy var switchAutoJoinAllNetworks = UISwitch()

    private enum Sections: Int, EnumsBuilder {
        case useVpnWifiProtection = 0
        case autoConnectAllNetworksSettings
        case current
        case available
        case trusted
    }
    
    private struct Cells {
        static let network = "NetworkCell"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = L10n.Settings.Hotspothelper.title
        self.hotspotHelper = PIAHotspotHelper(withDelegate: self)
        self.switchAutoJoinAllNetworks.addTarget(self, action: #selector(toggleAutoconnectWithAllNetworks(_:)), for: .valueChanged)
        self.switchWiFiProtection.addTarget(self, action: #selector(toggleUseWiFiProtection(_:)), for: .valueChanged)

        configureTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        filterAvailableNetworks()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Restylable
    
    override func viewShouldRestyle() {
        super.viewShouldRestyle()
        
        // XXX: for some reason, UITableView is not affected by appearance updates
        if let viewContainer = viewContainer {
            Theme.current.applyLightBackground(viewContainer)
        }
        Theme.current.applyLightBackground(tableView)
        Theme.current.applyDividerToSeparator(tableView)
    }
    
    @objc private func toggleAutoconnectWithAllNetworks(_ sender: UISwitch) {
        let preferences = Client.preferences.editable()
        preferences.shouldConnectForAllNetworks = sender.isOn
        preferences.commit()
    }
    
    @objc private func toggleUseWiFiProtection(_ sender: UISwitch) {
        let preferences = Client.preferences.editable()
        preferences.useWiFiProtection = sender.isOn
        preferences.commit()
        filterAvailableNetworks()
    }

    // MARK: Private Methods
    private func configureTableView() {
        if #available(iOS 11, *) {
            tableView.sectionFooterHeight = UITableViewAutomaticDimension
            tableView.estimatedSectionFooterHeight = 1.0
        }
        filterAvailableNetworks()
    }
    
    private func filterAvailableNetworks() {
        self.availableNetworks = Client.preferences.availableNetworks
        self.trustedNetworks = Client.preferences.trustedNetworks
        self.availableNetworks = self.availableNetworks.filter { !self.trustedNetworks.contains($0) }
        self.tableView.reloadData()
    }
    
}

extension TrustedNetworksViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Client.preferences.useWiFiProtection ? Sections.countCases() : 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Sections.objectIdentifyBy(index: section) {
        case .useVpnWifiProtection:
            return L10n.Settings.Hotspothelper.title.uppercased()
        case .current:
            return L10n.Settings.TrustedNetworks.Sections.current.uppercased()
        case .available:
            return L10n.Settings.TrustedNetworks.Sections.available.uppercased()
        case .trusted:
            return L10n.Settings.TrustedNetworks.Sections.trusted.uppercased()
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Sections.objectIdentifyBy(index: section) {
        case .useVpnWifiProtection:
            return L10n.Settings.Hotspothelper.Enable.description
        case .trusted:
            return L10n.Settings.TrustedNetworks.message
        case .autoConnectAllNetworksSettings:
            return L10n.Settings.Hotspothelper.All.description
        case .available:
            return availableNetworks.isEmpty ?
                L10n.Settings.Hotspothelper.Available.help :
                L10n.Settings.Hotspothelper.Available.Add.help
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections.objectIdentifyBy(index: section) {
        case .current:
            return hotspotHelper.currentWiFiNetwork() != nil ? 1 : 0
        case .available:
            return availableNetworks.count
        case .trusted:
            return trustedNetworks.count
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cells.network, for: indexPath)
        cell.selectionStyle = .default
        cell.accessoryView = nil
        cell.isUserInteractionEnabled = true
        cell.imageView?.image = Asset.iconWifi.image.withRenderingMode(.alwaysTemplate)
        cell.imageView?.tintColor = Theme.current.palette.textColor(forRelevance: 3, appearance: .dark)

        switch Sections.objectIdentifyBy(index: indexPath.section) {
        case .current:
            if let ssid = hotspotHelper.currentWiFiNetwork() {
                if trustedNetworks.contains(ssid) {
                    cell.isUserInteractionEnabled = false
                } else {
                    cell.accessoryView = UIImageView(image: Asset.iconAdd.image)
                }
                cell.textLabel?.text = ssid
            }
        case .available:
            cell.accessoryView = UIImageView(image: Asset.iconAdd.image)
            cell.textLabel?.text = availableNetworks[indexPath.row]
        case .trusted:
            cell.accessoryView = UIImageView(image: Asset.iconRemove.image)
            cell.selectionStyle = .none
            cell.textLabel?.text = trustedNetworks[indexPath.row]
        case .autoConnectAllNetworksSettings:
            cell.imageView?.image = nil
            cell.textLabel?.text = L10n.Settings.Hotspothelper.All.title
            cell.accessoryView = switchAutoJoinAllNetworks
            cell.selectionStyle = .none
            switchAutoJoinAllNetworks.isOn = Client.preferences.shouldConnectForAllNetworks
        case .useVpnWifiProtection:
            cell.imageView?.image = nil
            cell.textLabel?.text = L10n.Global.enabled
            cell.accessoryView = switchWiFiProtection
            cell.selectionStyle = .none
            switchWiFiProtection.isOn = Client.preferences.useWiFiProtection

        }

        Theme.current.applySolidLightBackground(cell)
        Theme.current.applyDetailTableCell(cell)

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Sections.objectIdentifyBy(index: indexPath.section) {
        case .current:
            if let ssid = hotspotHelper.currentWiFiNetwork() {
                hotspotHelper.saveTrustedNetwork(ssid)
            }
        case .available:
            let ssid = availableNetworks[indexPath.row]
            hotspotHelper.saveTrustedNetwork(ssid)
        case .trusted:
            let ssid = trustedNetworks[indexPath.row]
            hotspotHelper.removeTrustedNetwork(ssid)
        default:
            break
        }
        filterAvailableNetworks()
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch Sections.objectIdentifyBy(index: indexPath.section) {
        case .trusted:
            return true
        default:
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let ssid = trustedNetworks[indexPath.row]
            hotspotHelper.removeTrustedNetwork(ssid)
            filterAvailableNetworks()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return L10n.Global.clear
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        Theme.current.applyTableSectionHeader(view)
    }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        Theme.current.applyTableSectionFooter(view)
    }

}

extension TrustedNetworksViewController: PIAHotspotHelperDelegate{
    
    func refreshAvailableNetworks(_ networks: [String]?) {
        if let networks = networks {
            self.availableNetworks = networks
            self.tableView.reloadData()
        }
    }
    
}
