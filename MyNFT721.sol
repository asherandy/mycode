// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NicMeta is ERC721Enumerable, Ownable {
    
    using Strings for uint256;
    //是否开始公售
    bool public _isSaleActive =true;

    //是否开启盲盒
    bool public _revealed = false;

     // Constants
    //最大供应量
    uint256 public constant MAX_SUPPLY = 3333;

    //公售价格  前1000个0.01元 后面的 0.03
    uint256 public mintPrice = 0.01 ether;
    // uint256 private mp003=300000000000000 wei;
    //uint256 private mp003=0.0003 ether;
    //uint256 private mp13=1;
    
    //钱包最大持有  
    uint256 public maxBalance = 2;

    //一次MINT最大数量
    uint256 public maxMint = 2;

    //NFT的JSON图片的ipfs
    string baseURI;

    //盲盒的ipfs
    string public notRevealedUri;

    //nft格式
    string public baseExtension = ".json";

    //存储已经MINT的NFT的ipfs地址
    mapping(uint256 => string) private _tokenURIs;

    // 记录已取数量
    uint32 private alreadyPopCount;
    // 池子
    mapping(uint => uint) public pool;

    // mint 开始时间
    uint256 public publicMintStart;

    //构造函数
    constructor(string memory initBaseURI, string memory initNotRevealedUri) ERC721("G1TE", "G1")
    {
        //设置json路径
        initBaseURI = "ipfs://QmXM6aChJkbDxBuVywGfcBPCsUU53SaPZ7zDeSJown69DC/";
        setBaseURI(initBaseURI); 
         //设置盲盒路径
         initNotRevealedUri="ipfs://QmZhfkQbGA8hsyUzWUUg2rEU8E58ScZtpKw8CJ6SgLjMoM";
         //initNotRevealedUri="ipfs://QmWq8nd4R6ejLyGU72pUgf5KSVqpM7aAEBWv83X2d1yEgJ";
        setNotRevealedURI(initNotRevealedUri);
    }

    //铸造  传递mint的数量
    function mint(uint256 tokenQuantity) public payable {

        //判断当前已经mint的加上本次mint的数量会不会超过最大供应量，超过则失败
        require(totalSupply() + tokenQuantity <= MAX_SUPPLY,"Sale would exceed max supply");

        //判断是否开始公售，不是则失败
        require(_isSaleActive, "Sale must be active to mint NicMetas");

        //判断当前用户所持有的加上本次mint的数量会不会超过每个钱包限制的数量，超过则失败
        require(balanceOf(msg.sender) + tokenQuantity <= maxBalance,"Sale would exceed max balance");

        //判断当前用户是否持有本次mint的金额，余额不足则失败
        require(tokenQuantity * mintPrice <= msg.value,"Not enough ether sent");

        //判断是否可以开始mint
        require(mintingActive(), "Minting has not started yet");

        //判断本次mint数量会不会超过单次限制的最大mint数量，超过则失败
        require(tokenQuantity <= maxMint, "Can only mint 2 tokens at a time");


        //开始mint
        _mintNicMeta(tokenQuantity);

    }


    //真正的mint方法
    function _mintNicMeta(uint256 tokenQuantity)  internal {
        //循环mint
        for (uint256 i = 0; i < tokenQuantity; i++) {
       
            // 这里要用随机数
             uint256 mintIndex = generateRandomId(1);

            //如果当前的存储nft数量小于总供应量，则进行mint
            if (totalSupply() < MAX_SUPPLY) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    // 获取仍可用于铸造的代币数量
    function availableSupply() public view returns (uint256) {
        return MAX_SUPPLY - totalSupply() ;
    }


    // 随机数
   function generateRandomId(uint salt) public returns(uint randomId) {
        // 已取出数要小于总数
        require(alreadyPopCount < MAX_SUPPLY, "already generate done");
        // 根据各种“随机值”生成hash值
        uint rand = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.number, salt, alreadyPopCount)));

        return randomId = getIndex(rand) + 1;
    }
  /**
     * 根据随机值从池子中取值
     */
    function getIndex(uint rand) internal returns (uint) {
        // 取剩下数组长度余数
        uint lastCount = MAX_SUPPLY - alreadyPopCount;
        uint index = rand % lastCount;
        // 该下标对应的值若 >0 则取真实下标对应的值
        uint target = pool[index];
        uint pointIndex = target > 0 ? target : index;
        // 获取最后一个元素
        target = pool[--lastCount];
        // 将index指向没有抽出去过的地址
        pool[index] = target > 0 ? target : lastCount;
        // 更新已取出数量
        alreadyPopCount++;
        return pointIndex;
    }
    
    // 判断当前时间是否大于开始时间
    function mintingActive() public view returns (bool) {
        return block.timestamp > publicMintStart;
    }


    //查询nft的ipfs数据
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){

        //判断当前tokenId是否存在，不存在则失败
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");

        //如果盲盒还没有开启，则返回盲盒的数据
        if (_revealed == false) {
            return notRevealedUri;
        }
        //返回ipfs数据
        string memory _tokenURI = _tokenURIs[tokenId];

        //拿到nft的json的ipfs
        string memory base = _baseURI();

        // 如果说nft的json的ipfs不存在，则直接返回单个当前nft的url
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // 如果说当前nft的url大于0.则返回拼接baseurl和当前nft的url后的地址
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // 不然就返回base的url+当前token的id+设置的后缀(.json)
        return string(abi.encodePacked(base, tokenId.toString(), baseExtension));
    }
    

    //查看当前的baseURI
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //开启或者关闭公售
    function flipSaleActive() public onlyOwner {
        _isSaleActive = !_isSaleActive;
    }

    // 自动更新开启盲盒，根据公售时间+48(172800 )小时   应该有个触发器 来执行这个操作、逻辑是 判断公式时间。当时间+48小时大于当前时间执行
    function revealedbyture() public onlyOwner {
        _revealed=true;
    }


    //开启或者关闭盲盒
    function flipReveal() public onlyOwner {
        _revealed = !_revealed;
    }
    
    //设置可以开始mint
    function MintStartdate(uint256 _MintStartdate) public onlyOwner {
        publicMintStart = _MintStartdate;
    }

    //设置mint的价格
    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    //价格分隔位置
    //function setmp13(uint256 _sm13) public onlyOwner{
    //    mp13=_sm13;
    //}

    // 新价格
   // function setmp003(uint256 _sm3) public onlyOwner{
   //     mp003 = _sm3;
   // }

    //设置盲盒的URI
    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }
    
    //设置baseURI
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    //nftURI返回的后缀格式(.json)
    function setBaseExtension(string memory _newBaseExtension) public onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    //设置钱包的最大持有量
    function setMaxBalance(uint256 _maxBalance) public onlyOwner {
        maxBalance = _maxBalance;
    }

    //设置单次最大的mint数量
    function setMaxMint(uint256 _maxMint) public onlyOwner {
        maxMint = _maxMint;
    }

    //提现
    function withdraw(address to) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }



}
