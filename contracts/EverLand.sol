pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract EverLand is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter[] private m_LandCounter;

    uint256 private constant MAX_SUPPLY = 124884;
    uint256 private constant MAX_PURCHASE = 200;

    address private PGAIAA = 0xa8b062dE9dB7D22D6Ad6ef64Dc6FE53B3cba4A80; // 0x723B17718289A91AF252D616DE2C77944962d122;

    uint256 private m_EpicPrice = 350; // $350
    uint256 private m_RegularPrice = 175; // $175

    bytes32 private m_MerkleRoot;

    uint256 private m_Reserve = 50000;

    bool private m_IsMintable = false;
    bool private m_IsPublic = false;
    bool private m_IsActive = false;
    uint256 private m_SaleDate = 1648756800;

    string private m_baseURI;

    uint256 private m_MarketingCommission = 25;

    struct Auction {
        uint256 price;
        uint256 unit;
        uint32 id;
        address creator;
    }

    struct WhiteListAmounts {
        uint256 epic;
        uint256 regular;
    }

    struct validateLand {
        uint256 landType;
        uint256 landSize;
    }

    mapping(uint256 => Auction) private m_Auctions;
    mapping(address => WhiteListAmounts) public m_WhiteListAmounts;
    mapping(uint256 => bool) private m_BurnList;

    Auction[] private m_AuctionsData;

    uint256 private gaiaUSDC =
        (((79357452196816930849001 * (10**18)) /
            uint256(1868548345305467327315244)) *
            1588085682360 *
            (10**12)) / uint256(1586020149070416559561266);

    constructor() ERC721("Eever", "EEVER") {
        for (uint256 i = 0; i < 10; i++) {
            Counters.Counter memory temp;
            m_LandCounter.push(temp);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from != address(0) && m_Auctions[tokenId].creator == from) {
            delete m_Auctions[tokenId];
            uint256 flag = 0;
            uint256 length = m_AuctionsData.length;
            while (length > 0) {
                if (m_AuctionsData[length - 1].id == tokenId) {
                    m_AuctionsData[length - 1] = m_AuctionsData[
                        m_AuctionsData.length - 1
                    ];
                    flag = 1;
                    break;
                }
                length = length - 1;
            }
            if (flag == 1) m_AuctionsData.pop();
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);

        uint256 gaiaBalance = IERC20(PGAIAA).balanceOf(address(this));
        IERC20(PGAIAA).transfer(msg.sender, gaiaBalance);
    }

    function _safeMintMultiple(
        address _address,
        uint256 _countOfLands,
        uint256 _landSize,
        uint256 _landType
    ) private {
        while (_countOfLands > 0) {
            m_LandCounter[_landSize * 2 + _landType].increment();
            uint256 tokenId = generateTokenId(
                m_LandCounter[_landSize * 2 + _landType].current(),
                _landSize,
                _landType
            );

            require(_validateIdOfLand(tokenId), "No Land Id");
            if (_exists(tokenId) || m_BurnList[tokenId]) continue;

            _safeMint(_address, tokenId);
            _countOfLands = _countOfLands.sub(1);
        }
    }

    function randomReserve(
        address _address,
        uint256 _countOfLands,
        uint256 _landSize,
        uint256 _landType
    ) external onlyOwner {
        _safeMintMultiple(_address, _countOfLands, _landSize, _landType);
    }

    function mint(
        uint256 _countOfLands,
        uint256 _landSize,
        uint256 _landType
    ) external {
        require(m_IsPublic, "Sale must be active to mint Lands");
        require(m_SaleDate < block.timestamp, "You can not mint yet");
        require(
            _countOfLands > 0 && _countOfLands <= MAX_PURCHASE,
            "Can only mint 200 tokens at a time"
        );
        // uint256 gaiaUSDC = getTokenPrice();
        uint8[5] memory _prices = [1, 3, 6, 12, 24];
        uint256 price = _landType == 1
            ? ((m_EpicPrice *
                _countOfLands *
                _prices[_landSize] *
                _prices[_landSize]) * (10**36)) / gaiaUSDC
            : ((m_RegularPrice *
                _countOfLands *
                _prices[_landSize] *
                _prices[_landSize]) * (10**36)) / gaiaUSDC;
        require(IERC20(PGAIAA).transferFrom(msg.sender, address(this), price));
        _safeMintMultiple(msg.sender, _countOfLands, _landSize, _landType);
    }

    function selectedMint(
        uint256 _countOfLands,
        uint256[] memory _ids,
        uint256 _index,
        uint256 _amount,
        bytes32[] memory _merkleProof
    ) external {
        require(m_IsMintable, "Sale must be active to mint Lands");
        require(
            _countOfLands > 0 && _countOfLands <= MAX_PURCHASE,
            "Can only mint 200 tokens at a time"
        );
        require(
            _ids.length == _countOfLands,
            "Length of id array must be count params"
        );
        for (uint256 i = 0; i < _countOfLands; i++) {
            for (uint256 j = i + 1; j < _countOfLands; j++) {
                require(_ids[i] != _ids[j], "ids must be not same each other");
            }
        }
        for (uint256 i = 0; i < _countOfLands; i++) {
            require(_validateIdOfLand(_ids[i]), "No Land Id");
            require(_exists(_ids[i]) == false, "Lands were already minted");
        }
        uint256 epicLands = 0;
        uint256 regularLands = 0;
        for (uint256 i = 0; i < _countOfLands; i++) {
            validateLand memory data = _validateTypeOfLand(_ids[i]);
            if (data.landType == 1) {
                epicLands = epicLands + data.landSize * data.landSize;
            } else {
                regularLands = regularLands + data.landSize * data.landSize;
            }
        }
        require(
            m_WhiteListAmounts[msg.sender].regular + regularLands <=
                _amount / 2 &&
                m_WhiteListAmounts[msg.sender].epic + epicLands <=
                _amount - _amount / 2,
            "WhiteList OverAmount"
        );

        bytes32 node = keccak256(abi.encodePacked(_index, msg.sender, _amount));
        require(
            MerkleProof.verify(_merkleProof, m_MerkleRoot, node),
            "Invalid proof."
        );

        m_WhiteListAmounts[msg.sender].epic =
            m_WhiteListAmounts[msg.sender].epic +
            epicLands;
        m_WhiteListAmounts[msg.sender].regular =
            m_WhiteListAmounts[msg.sender].regular +
            regularLands;

        for (uint256 i = 0; i < _countOfLands; i++) {
            _safeMint(msg.sender, _ids[i]);
        }
    }

    function generateTokenId(
        uint256 _id,
        uint256 _landSize, // 1 x 1: 0, 3 x 3: 1, ..., 24 x 24: 4
        uint256 _landType // epic 1, regular 0
    ) private pure returns (uint256) {
        return (_landSize * 2 + _landType) * 100000 + _id;
    }

    function isWhiteListVerify(
        uint256 _index,
        address _account,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) public view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(_index, _account, _amount));
        return MerkleProof.verify(_merkleProof, m_MerkleRoot, node);
    }

    function getTokenPrice() public view returns (uint256) {
        address pairAddress1 = address(
            0x885eb7D605143f454B4345aea37ee8bc457EC730
        );
        IUniswapV2Pair pair1 = IUniswapV2Pair(pairAddress1);
        (uint256 Res0, uint256 Res1, ) = pair1.getReserves();
        uint256 price1 = (Res1 * (10**18)) / Res0;

        address pairAddress2 = address(
            0xCD578F016888B57F1b1e3f887f392F0159E26747
        );
        IUniswapV2Pair pair2 = IUniswapV2Pair(pairAddress2);
        (uint256 Re0, uint256 Re1, ) = pair2.getReserves();
        uint256 price2 = (Re0 * (10**30)) / Re1;
        return (price1 * price2) / (10**18);
    }

    function _validateTypeOfLand(uint256 _id)
        private
        pure
        returns (validateLand memory)
    {
        validateLand memory data;
        if (_id > 900000 && _id <= 900020) {
            data.landType = 1;
            data.landSize = 24;
        } else if (_id > 800000 && _id <= 800032) {
            data.landType = 0;
            data.landSize = 24;
        } else if (_id > 700000 && _id <= 700070) {
            data.landType = 1;
            data.landSize = 12;
        } else if (_id > 600000 && _id <= 600130) {
            data.landType = 0;
            data.landSize = 12;
        } else if (_id > 500000 && _id <= 500270) {
            data.landType = 1;
            data.landSize = 6;
        } else if (_id > 400000 && _id <= 400540) {
            data.landType = 0;
            data.landSize = 6;
        } else if (_id > 300000 && _id <= 301080) {
            data.landType = 1;
            data.landSize = 3;
        } else if (_id > 200000 && _id <= 202170) {
            data.landType = 0;
            data.landSize = 3;
        } else if (_id > 100000 && _id <= 138960) {
            data.landType = 1;
            data.landSize = 1;
        } else if (_id > 0 && _id <= 81612) {
            data.landType = 0;
            data.landSize = 1;
        }
        return data;
    }

    function _validateIdOfLand(uint256 _id) private pure returns (bool) {
        return
            (_id > 900000 && _id <= 900020) ||
            (_id > 800000 && _id <= 800032) ||
            (_id > 700000 && _id <= 700070) ||
            (_id > 600000 && _id <= 600130) ||
            (_id > 500000 && _id <= 500270) ||
            (_id > 400000 && _id <= 400540) ||
            (_id > 300000 && _id <= 301080) ||
            (_id > 200000 && _id <= 202170) ||
            (_id > 100000 && _id <= 138960) ||
            (_id > 0 && _id <= 81612);
    }

    function openTrade(
        uint32 _id,
        uint256 _price,
        uint256 _unit
    ) external {
        require(m_IsActive, "Sale must be active to mint GaiaLand");
        require(ownerOf(_id) == msg.sender, "sender is not owner");
        require(m_Auctions[_id].id != _id, "Already opened");
        m_Auctions[_id] = Auction({
            price: _price,
            unit: _unit,
            creator: msg.sender,
            id: _id
        });
        Auction memory temp = Auction({
            price: _price,
            unit: _unit,
            creator: msg.sender,
            id: _id
        });
        m_AuctionsData.push(temp);
    }

    function closeTrade(uint256 _id) external {
        require(m_IsActive, "Sale must be active to mint GaiaLand");
        require(ownerOf(_id) == msg.sender, "sender is not owner");
        require(m_Auctions[_id].id == _id, "Already closed");
        delete m_Auctions[_id];
        uint256 length = m_AuctionsData.length;
        while (length > 0) {
            if (m_AuctionsData[length - 1].id == _id) {
                m_AuctionsData[length - 1] = m_AuctionsData[
                    m_AuctionsData.length - 1
                ];
                break;
            }
            length = length - 1;
        }
        m_AuctionsData.pop();
    }

    function buy(uint256 _id) external payable {
        require(m_IsActive, "Sale must be active to mint GaiaLand");
        require(ownerOf(_id) != msg.sender, "Can not buy what you own");
        require(m_Auctions[_id].id == _id, "Item not listed currently");
        require(
            m_Auctions[_id].price <= msg.value,
            "Error, price is not match"
        );
        require(m_Auctions[_id].unit == 2, "Error, unit is not match");
        address _previousOwner = m_Auctions[_id].creator;
        address _newOwner = msg.sender;

        uint256 _commissionValue = msg.value.mul(m_MarketingCommission).div(
            1000
        );
        uint256 _sellerValue = msg.value.sub(_commissionValue);
        payable(_previousOwner).transfer(_sellerValue);
        _transfer(_previousOwner, _newOwner, _id);
        delete m_Auctions[_id];
        uint256 length = m_AuctionsData.length;
        while (length > 0) {
            if (m_AuctionsData[length - 1].id == _id) {
                m_AuctionsData[length - 1] = m_AuctionsData[
                    m_AuctionsData.length - 1
                ];
                break;
            }
            length = length - 1;
        }
        m_AuctionsData.pop();
    }

    function buyToken(uint256 _id, uint256 _price) external {
        require(m_IsActive, "Sale must be active to mint GaiaLand");
        require(ownerOf(_id) != msg.sender, "Can not buy what you own");
        require(m_Auctions[_id].id == _id, "Item not listed currently");
        require(m_Auctions[_id].price <= _price, "Error, price is not match");
        require(m_Auctions[_id].unit == 1, "Error, unit is not match");
        address _previousOwner = m_Auctions[_id].creator;
        address _newOwner = msg.sender;

        uint256 _commissionValue = _price.mul(m_MarketingCommission).div(1000);
        uint256 _sellerValue = _price.sub(_commissionValue);

        require(
            IERC20(PGAIAA).transferFrom(
                msg.sender,
                address(this),
                _commissionValue
            )
        );
        require(
            IERC20(PGAIAA).transferFrom(
                msg.sender,
                _previousOwner,
                _sellerValue
            )
        );

        _transfer(_previousOwner, _newOwner, _id);
        delete m_Auctions[_id];
        uint256 length = m_AuctionsData.length;
        while (length > 0) {
            if (m_AuctionsData[length - 1].id == _id) {
                m_AuctionsData[length - 1] = m_AuctionsData[
                    m_AuctionsData.length - 1
                ];
                break;
            }
            length = length - 1;
        }
        m_AuctionsData.pop();
    }

    function customReserve(address _address, uint256[] memory ids)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < ids.length; i++) {
            require(ids[i] <= MAX_SUPPLY);
            require(!_exists(ids[i]), "Token id exists.");
            if (m_BurnList[ids[i]]) m_BurnList[ids[i]] = false;

            _safeMint(_address, ids[i]);
        }
    }

    function burn(uint256 _tokenId) external onlyOwner {
        _burn(_tokenId);
        m_BurnList[_tokenId] = true;
    }

    // ######## EverLand Config #########
    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }

    function getMaxPurchase() external pure returns (uint256) {
        return MAX_PURCHASE;
    }

    function setEpicPrice(uint256 _epicPrice) external onlyOwner {
        m_EpicPrice = _epicPrice;
    }

    function getEpicPrice() external view returns (uint256) {
        return m_EpicPrice;
    }

    function setRegularPrice(uint256 _regularPrice) external onlyOwner {
        m_RegularPrice = _regularPrice;
    }

    function getRegularPrice() external view returns (uint256) {
        return m_RegularPrice;
    }

    function setMintEnabled(bool _enabled) external onlyOwner {
        m_IsMintable = _enabled;
        if (_enabled) m_IsActive = _enabled;
    }

    function getMintEnabled() external view returns (bool) {
        return m_IsMintable;
    }

    function setPublicMintEnabled(bool _enabled) external onlyOwner {
        m_IsPublic = _enabled;
        if (_enabled) m_IsActive = _enabled;
    }

    function getPublicMintEnabled() external view returns (bool) {
        return m_IsPublic;
    }

    function setActiveEnabled(bool _enabled) external onlyOwner {
        m_IsActive = _enabled;
    }

    function getActiveEnabled() external view returns (bool) {
        return m_IsActive;
    }

    function setSaleDate(uint256 _date) external onlyOwner {
        m_SaleDate = _date;
    }

    function getSaleDate() external view returns (uint256) {
        return m_SaleDate;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        m_MerkleRoot = _merkleRoot;
    }

    function getMerkleRoot() external view returns (bytes32) {
        return m_MerkleRoot;
    }

    function setReserve(uint256 _reserve) external onlyOwner {
        m_Reserve = _reserve;
    }

    function getReserve() external view returns (uint256) {
        return m_Reserve;
    }

    function setPGAIAContract(address _address) external onlyOwner {
        PGAIAA = _address;
    }

    function getPGAIAContract() external view returns (address) {
        return PGAIAA;
    }

    function setMarketingCommission(uint256 _commission) external onlyOwner {
        m_MarketingCommission = _commission;
    }

    function getMarketingCommission() external view returns (uint256) {
        return m_MarketingCommission;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        m_baseURI = _newBaseURI;
    }

    function getAuctionsData() external view returns (Auction[] memory) {
        return m_AuctionsData;
    }

    function _baseURI() internal view override returns (string memory) {
        return m_baseURI;
    }
}
